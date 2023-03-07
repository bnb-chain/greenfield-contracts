// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/structs/DoubleEndedQueueUpgradeable.sol";

import "./AccessControl.sol";
import "./NFTWrapResourceHub.sol";
import "../interface/ICrossChain.sol";
import "../interface/IERC721NonTransferable.sol";
import "../lib/RLPDecode.sol";
import "../lib/RLPEncode.sol";

contract ObjectHub is NFTWrapResourceHub, AccessControl {
    using DoubleEndedQueueUpgradeable for DoubleEndedQueueUpgradeable.Bytes32Deque;
    using RLPEncode for *;
    using RLPDecode for *;

    function initialize(address _ERC721_token, address _additional) public initializer {
        ERC721Token = _ERC721_token;
        additional = _additional;

        relayFee = 2e15;
        ackRelayFee = 2e15;
        callbackGasPrice = 1e9;
        transferGas = 2300;

        channelId = OBJECT_CHANNEL_ID;
    }

    /*----------------- middle-layer app function -----------------*/

    /**
     * @dev handle sync cross-chain package from BSC to GNFD
     *
     * @param msgBytes The rlp encoded message bytes sent from BSC to GNFD
     */
    function handleSynPackage(uint8, bytes calldata msgBytes)
        external
        override
        onlyCrossChainContract
        returns (bytes memory)
    {
        return _handleMirrorSynPackage(msgBytes);
    }

    // TODO: create object
    /**
     * @dev handle ack cross-chain package from GNFD，it means create/delete operation handled by GNFD successfully.
     *
     * @param sequence The sequence of the ack package
     * @param msgBytes The rlp encoded message bytes sent from GNFD
     */
    function handleAckPackage(uint8, uint64 sequence, bytes calldata msgBytes)
        external
        override
        onlyCrossChainContract
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
        if (opType == TYPE_DELETE) {
            extraData = _handleDeleteAckPackage(pkgIter);
        } else {
            revert("unexpected operation type");
        }

        uint256 refundFee = CALLBACK_GAS_LIMIT * callbackGasPrice;
        if (extraData.failureHandleStrategy != FailureHandleStrategy.NoCallBack) {
            uint256 gasBefore = gasleft();
            bytes32 pkgHash = keccak256(abi.encodePacked(channelId, sequence));
            try IApplication(extraData.appAddress).handleAckPackage{gas: CALLBACK_GAS_LIMIT}(
                channelId, msgBytes, extraData.callbackData
            ) {} catch (bytes memory reason) {
                if (extraData.failureHandleStrategy != FailureHandleStrategy.Skip) {
                    packageMap[pkgHash] = RetryPackage(extraData.appAddress, msgBytes, extraData.callbackData, false, reason);
                    retryQueue[extraData.appAddress].pushBack(pkgHash);
                }
            }

            uint256 gasUsed = gasleft() - gasBefore;
            refundFee = (CALLBACK_GAS_LIMIT - gasUsed) * callbackGasPrice;
        }

        // refund
        (bool success,) = extraData.refundAddress.call{gas: transferGas, value: refundFee}("");
        require(success, "refund failed");
    }

    /**
     * @dev handle failed ack cross-chain package from GNFD, it means failed to cross-chain syn request to GNFD.
     *
     * @param sequence The sequence of the fail ack package
     * @param msgBytes The rlp encoded message bytes sent from GNFD
     */
    function handleFailAckPackage(uint8 channelId, uint64 sequence, bytes calldata msgBytes)
        external
        override
        onlyCrossChainContract
    {
        (ExtraData memory extraData, bool success) = _decodeFailAckPackage(msgBytes);
        require(success, "decode fail ack package failed");

        uint256 refundFee = CALLBACK_GAS_LIMIT * callbackGasPrice;
        if (extraData.failureHandleStrategy != FailureHandleStrategy.NoCallBack) {
            uint256 gasBefore = gasleft();
            bytes32 pkgHash = keccak256(abi.encodePacked(channelId, sequence));
            try IApplication(extraData.appAddress).handleAckPackage{gas: CALLBACK_GAS_LIMIT}(
                channelId, msgBytes, extraData.callbackData
            ) {} catch (bytes memory reason) {
                if (extraData.failureHandleStrategy != FailureHandleStrategy.Skip) {
                    packageMap[pkgHash] = RetryPackage(extraData.appAddress, msgBytes, extraData.callbackData, true, reason);
                    retryQueue[extraData.appAddress].pushBack(pkgHash);
                }
            }

            uint256 gasUsed = gasleft() - gasBefore;
            refundFee = (CALLBACK_GAS_LIMIT - gasUsed) * callbackGasPrice;
        }

        // refund
        (success,) = extraData.refundAddress.call{gas: transferGas, value: refundFee}("");
        require(success, "refund failed");

        emit FailAckPkgReceived(channelId, msgBytes);
    }

    /*----------------- external function -----------------*/
    /**
     * @dev delete a Object and send cross-chain request from BSC to GNFD
     *
     * @param id The bucket's id
     */
    function deleteObject(uint256 id) external payable returns (bool) {
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
        if (opType == TYPE_DELETE) {
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
        }
    }
}
