// SPDX-License-Identifier: GPL-3.0-or-later

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

    // package type
    bytes32 public constant CREATE_BUCKET_SYN = keccak256("CREATE_BUCKET_SYN");

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
    function handleAckPackage(
        uint8,
        uint64 sequence,
        bytes calldata msgBytes,
        uint256 callbackGasLimit
    ) external override onlyCrossChain returns (uint256 remainingGas, address refundAddress) {
        RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();

        uint8 opType = uint8(iter.next().toUint());
        bytes memory pkgBytes;
        if (iter.hasNext()) {
            pkgBytes = iter.next().toBytes();
        } else {
            revert("wrong ack package");
        }

        if (opType == TYPE_CREATE) {
            (remainingGas, refundAddress) = _handleCreateAckPackage(pkgBytes, sequence, callbackGasLimit);
        } else if (opType == TYPE_DELETE) {
            (remainingGas, refundAddress) = _handleDeleteAckPackage(pkgBytes, sequence, callbackGasLimit);
        } else {
            revert("unexpected operation type");
        }
    }

    /**
     * @dev handle failed ack cross-chain package from GNFD, it means failed to cross-chain syn request to GNFD.
     *
     * @param sequence The sequence of the fail ack package
     * @param msgBytes The rlp encoded message bytes sent from GNFD
     * @param callbackGasLimit The gas limit for callback
     */
    function handleFailAckPackage(
        uint8 channelId,
        uint64 sequence,
        bytes calldata msgBytes,
        uint256 callbackGasLimit
    ) external override onlyCrossChain returns (uint256 remainingGas, address refundAddress) {
        RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();

        uint8 opType = uint8(iter.next().toUint());
        bytes memory pkgBytes;
        if (iter.hasNext()) {
            pkgBytes = iter.next().toBytes();
        } else {
            revert("wrong failAck package");
        }

        if (opType == TYPE_CREATE) {
            (remainingGas, refundAddress) = _handleCreateFailAckPackage(pkgBytes, sequence, callbackGasLimit);
        } else if (opType == TYPE_DELETE) {
            (remainingGas, refundAddress) = _handleDeleteFailAckPackage(pkgBytes, sequence, callbackGasLimit);
        } else {
            revert("unexpected operation type");
        }

        emit FailAckPkgReceived(channelId, msgBytes);
    }

    /*----------------- external function -----------------*/
    function versionInfo()
        external
        pure
        override
        returns (uint256 version, string memory name, string memory description)
    {
        return (400_001, "BucketHub", "init version");
    }

    function createBucket(CreateBucketSynPackage memory) external payable returns (bool) {
        delegateAdditional();
    }

    function createBucket(CreateBucketSynPackage memory, uint256, ExtraData memory) external payable returns (bool) {
        delegateAdditional();
    }

    function deleteBucket(uint256) external payable returns (bool) {
        delegateAdditional();
    }

    function deleteBucket(uint256, uint256, ExtraData memory) external payable returns (bool) {
        delegateAdditional();
    }

    /*----------------- internal function -----------------*/
    function _decodeCreateBucketSynPackage(
        bytes memory pkgBytes
    ) internal pure returns (CreateBucketSynPackage memory synPkg, bool success) {
        RLPDecode.Iterator memory iter = pkgBytes.toRLPItem().iterator();

        uint256 idx;
        while (iter.hasNext()) {
            if (idx == 0) {
                synPkg.creator = iter.next().toAddress();
            } else if (idx == 1) {
                synPkg.name = string(iter.next().toBytes());
            } else if (idx == 2) {
                synPkg.visibility = BucketVisibilityType(iter.next().toUint());
            } else if (idx == 3) {
                synPkg.paymentAddress = iter.next().toAddress();
            } else if (idx == 4) {
                synPkg.primarySpAddress = iter.next().toAddress();
            } else if (idx == 5) {
                synPkg.primarySpApprovalExpiredHeight = iter.next().toUint();
            } else if (idx == 6) {
                synPkg.primarySpSignature = iter.next().toBytes();
            } else if (idx == 7) {
                synPkg.chargedReadQuota = uint64(iter.next().toUint());
            } else if (idx == 8) {
                synPkg.extraData = iter.next().toBytes();
                success = true;
            } else {
                break;
            }
            idx++;
        }
        return (synPkg, success);
    }

    function _handleCreateFailAckPackage(
        bytes memory pkgBytes,
        uint64 sequence,
        uint256 callbackGasLimit
    ) internal returns (uint256 remainingGas, address refundAddress) {
        (CreateBucketSynPackage memory synPkg, bool success) = _decodeCreateBucketSynPackage(pkgBytes);
        require(success, "unrecognized create bucket fail ack package");

        if (synPkg.extraData.length > 0) {
            ExtraData memory extraData;
            (extraData, success) = _bytesToExtraData(synPkg.extraData);
            require(success, "unrecognized extra data");

            if (extraData.appAddress != address(0) && callbackGasLimit >= 2300) {
                bytes memory reason;
                bool failed;
                uint256 gasBefore = gasleft();
                try
                    IApplication(extraData.appAddress).handleFailAckPackage{ gas: callbackGasLimit }(
                        channelId,
                        synPkg,
                        extraData.callbackData
                    )
                {} catch Error(string memory error) {
                    reason = bytes(error);
                    failed = true;
                } catch (bytes memory lowLevelData) {
                    reason = lowLevelData;
                    failed = true;
                }

                remainingGas = callbackGasLimit > (gasBefore - gasleft())
                    ? callbackGasLimit - (gasBefore - gasleft())
                    : 0;
                refundAddress = extraData.refundAddress;

                if (failed) {
                    bytes32 pkgHash = keccak256(abi.encodePacked(channelId, sequence));
                    emit AppHandleAckPkgFailed(extraData.appAddress, pkgHash, reason);
                    if (extraData.failureHandleStrategy != FailureHandleStrategy.SkipOnFail) {
                        packageMap[pkgHash] = CallbackPackage(
                            extraData.appAddress,
                            CREATE_BUCKET_SYN,
                            pkgBytes,
                            extraData.callbackData,
                            true,
                            reason
                        );
                        retryQueue[extraData.appAddress].pushBack(pkgHash);
                    }
                }
            }
        }
    }
}
