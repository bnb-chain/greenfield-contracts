// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/structs/DoubleEndedQueueUpgradeable.sol";

import "./AccessControl.sol";
import "./NFTWrapResourceHub.sol";
import "../interface/IERC721NonTransferable.sol";
import "../lib/RLPDecode.sol";
import "../lib/RLPEncode.sol";

contract BucketHub is NFTWrapResourceHub, AccessControl {
    using DoubleEndedQueueUpgradeable for DoubleEndedQueueUpgradeable.Bytes32Deque;
    using RLPEncode for *;
    using RLPDecode for *;

    /*----------------- struct -----------------*/
    // BSC to GNFD
    struct CreateSynPackage {
        address creator;
        string name;
        bool isPublic;
        address paymentAddress;
        address primarySpAddress;
        uint256 primarySpApprovalExpiredHeight;
        bytes primarySpSignature; // TODO if the owner of the bucket is a smart contract, we are not able to get the primarySpSignature
        uint8 readQuota;
        bytes extraData; // rlp encode of ExtraData
    }

    function initialize(address _ERC721_token, address _additional) public initializer {
        ERC721Token = _ERC721_token;
        additional = _additional;

        channelId = BUCKET_CHANNEL_ID;
    }

    /*----------------- middle-layer app function -----------------*/

    /**
     * @dev handle sync cross-chain package from BSC to GNFD
     *
     * @param msgBytes The rlp encoded message bytes sent from BSC to GNFD
     */
    function handleSynPackage(uint8, bytes calldata msgBytes) external override onlyCrossChain returns (bytes memory) {
        return _handleMirrorSynPackage(msgBytes);
    }

    /**
     * @dev handle ack cross-chain package from GNFD，it means create/delete operation handled by GNFD successfully.
     *
     * @param sequence The sequence of the ack package
     * @param msgBytes The rlp encoded message bytes sent from GNFD
     * @param callbackGasLimit The gas limit for callback
     */
    function handleAckPackage(uint8, uint64 sequence, bytes calldata msgBytes, uint256 callbackGasLimit)
        external
        override
        onlyCrossChain
        returns (uint256 remainingGas, address refundAddress)
    {
        RLPDecode.Iterator memory msgIter = msgBytes.toRLPItem().iterator();

        uint8 opType = uint8(msgIter.next().toUint());
        RLPDecode.Iterator memory pkgIter;
        if (msgIter.hasNext()) {
            pkgIter = msgIter.next().toBytes().toRLPItem().iterator();
        } else {
            revert("wrong ack package");
        }

        ExtraData memory extraData;
        if (opType == TYPE_CREATE) {
            extraData = _handleCreateAckPackage(pkgIter);
        } else if (opType == TYPE_DELETE) {
            extraData = _handleDeleteAckPackage(pkgIter);
        } else {
            revert("unexpected operation type");
        }

        if (extraData.appAddress != address(0)) {
            uint256 gasBefore = gasleft();
            bytes32 pkgHash = keccak256(abi.encodePacked(channelId, sequence));

            bytes memory reason;
            try IApplication(extraData.appAddress).handleAckPackage{gas: callbackGasLimit}(
                channelId, msgBytes, extraData.callbackData
            ) {} catch Error(string memory error) {
                reason = bytes(error);
            } catch (bytes memory lowLevelData) {
                reason = lowLevelData;
            }

            if (reason.length > 0) {
                emit AppHandleAckPkgFailed(extraData.appAddress, pkgHash, reason);
                if (extraData.failureHandleStrategy != FailureHandleStrategy.SkipAckPackage) {
                    packageMap[pkgHash] =
                        RetryPackage(extraData.appAddress, msgBytes, extraData.callbackData, true, reason);
                    retryQueue[extraData.appAddress].pushBack(pkgHash);
                }
            }

            remainingGas = callbackGasLimit - (gasBefore - gasleft()); // gas limit - gas used
            refundAddress = extraData.refundAddress;
        }
    }

    /**
     * @dev handle failed ack cross-chain package from GNFD, it means failed to cross-chain syn request to GNFD.
     *
     * @param sequence The sequence of the fail ack package
     * @param msgBytes The rlp encoded message bytes sent from GNFD
     * @param callbackGasLimit The gas limit for callback
     */
    function handleFailAckPackage(uint8 channelId, uint64 sequence, bytes calldata msgBytes, uint256 callbackGasLimit)
        external
        override
        onlyCrossChain
        returns (uint256 remainingGas, address refundAddress)
    {
        (ExtraData memory extraData, bool success) = _decodeFailAckPackage(msgBytes);
        require(success, "decode fail ack package failed");

        if (extraData.appAddress != address(0)) {
            uint256 gasBefore = gasleft();
            bytes32 pkgHash = keccak256(abi.encodePacked(channelId, sequence));

            bytes memory reason;
            try IApplication(extraData.appAddress).handleFailAckPackage{gas: callbackGasLimit}(
                channelId, msgBytes, extraData.callbackData
            ) {} catch Error(string memory error) {
                reason = bytes(error);
            } catch (bytes memory lowLevelData) {
                reason = lowLevelData;
            }

            if (reason.length > 0) {
                emit AppHandleFailAckPkgFailed(extraData.appAddress, pkgHash, reason);
                if (extraData.failureHandleStrategy != FailureHandleStrategy.SkipAckPackage) {
                    packageMap[pkgHash] =
                        RetryPackage(extraData.appAddress, msgBytes, extraData.callbackData, true, reason);
                    retryQueue[extraData.appAddress].pushBack(pkgHash);
                }
            }

            remainingGas = callbackGasLimit - (gasBefore - gasleft()); // gas limit - gas used
            refundAddress = extraData.refundAddress;
        }

        emit FailAckPkgReceived(channelId, msgBytes);
    }

    /*----------------- external function -----------------*/
    function upgradeInfo() external pure override returns (uint256 version, string memory name, string memory description) {
        return (400_001, "BucketHub", "init version");
    }

    function createBucket(CreateSynPackage memory) external payable returns (bool) {
        delegateAdditional();
    }

    function createBucket(CreateSynPackage memory, ExtraData memory) external payable returns (bool) {
        delegateAdditional();
    }

    function deleteBucket(uint256) external payable returns (bool) {
        delegateAdditional();
    }

    function deleteBucket(uint256, ExtraData memory) external payable returns (bool) {
        delegateAdditional();
    }

    /*----------------- internal function -----------------*/
    function _decodeFailAckPackage(bytes memory msgBytes)
        internal
        pure
        returns (ExtraData memory extraData, bool success)
    {
        RLPDecode.Iterator memory msgIter = msgBytes.toRLPItem().iterator();

        uint8 opType = uint8(msgIter.next().toUint());
        RLPDecode.Iterator memory pkgIter;
        if (msgIter.hasNext()) {
            pkgIter = msgIter.next().toBytes().toRLPItem().iterator();
        } else {
            return (extraData, false);
        }

        uint256 elementsNum;
        if (opType == TYPE_CREATE) {
            elementsNum = 9;
        } else if (opType == TYPE_DELETE) {
            elementsNum = 3;
        } else {
            return (extraData, false);
        }

        for (uint256 i = 0; i < elementsNum - 1; i++) {
            if (pkgIter.hasNext()) {
                pkgIter.next();
            } else {
                return (extraData, false);
            }
        }

        if (pkgIter.hasNext()) {
            (extraData, success) = _bytesToExtraData(pkgIter.next().toBytes());
        } else {
            // empty extra data
            return (extraData, true);
        }
    }
}
