// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/structs/DoubleEndedQueueUpgradeable.sol";

import "../Config.sol";
import "../CrossChain.sol";
import "../PackageQueue.sol";
import "../interface/IApplication.sol";
import "../interface/ICrossChain.sol";
import "../lib/RLPDecode.sol";
import "../lib/RLPEncode.sol";

contract EndPoint is Config, PackageQueue {
    using DoubleEndedQueueUpgradeable for DoubleEndedQueueUpgradeable.Bytes32Deque;
    using RLPEncode for *;
    using RLPDecode for *;

    uint8 public constant EVENT_SEND = 0x01;

    modifier onlyCrossChain() {
        require(msg.sender == CROSS_CHAIN, "only cross chain contract");
        _;
    }

    constructor() {
        channelId = APP_CHANNEL_ID;

        relayFee = 2e15;
        ackRelayFee = 2e15;
        callBackGasPrice = 1e9;
        transferGas = 2300;
    }

    // @notice send a cross-chain application message to GNFD
    // @param _appPayload - a custom bytes payload to send to the destination contract
    // @param _refundAddress - if the source transaction is cheaper than the amount of value passed, refund the additional amount to this address
    function send(bytes calldata _appMsg, address payable _refundAddress) external payable {
        address _appAddress = msg.sender;
        FailureHandleStrategy failStrategy = failureHandleMap[_appAddress];
        require(failStrategy != FailureHandleStrategy.Closed, "application closed");

        require(msg.value >= relayFee + ackRelayFee + callBackGasPrice * CALLBACK_GAS_LIMIT, "not enough relay fee");
        uint256 _ackRelayFee = msg.value - relayFee - callBackGasPrice * CALLBACK_GAS_LIMIT;

        // check package queue
        if (failStrategy == FailureHandleStrategy.HandleInOrder) {
            require(
                retryQueue[_appAddress].length() == 0,
                "retry queue is not empty, please process the previous package first"
            );
        }

        // check refund address
        (bool success,) = _refundAddress.call{gas: transferGas}("");
        require(success && (_refundAddress != address(0)), "invalid refund address"); // the refund address must be payable

        bytes[] memory elements = new bytes[](5);
        elements[0] = _appAddress.encodeAddress();
        elements[1] = _refundAddress.encodeAddress();
        elements[4] = uint8(failureHandleMap[_appAddress]).encodeUint();
        elements[5] = _appMsg.encodeBytes();

        bytes memory msgBytes = _RLPEncode(EVENT_SEND, elements.encodeList());
        ICrossChain(CROSS_CHAIN).sendSynPackage(channelId, msgBytes, relayFee, _ackRelayFee);
    }

    function handleAckPackage(uint8 channelId, uint64 sequence, bytes calldata msgBytes) external onlyCrossChain {
        RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();

        uint8 status;
        uint8 errCode;
        bytes memory packBytes;
        bool success;
        uint256 idx;
        while (iter.hasNext()) {
            if (idx == 0) {
                status = uint8(iter.next().toUint());
            } else if (idx == 1) {
                errCode = uint8(iter.next().toUint());
            } else if (idx == 2) {
                packBytes = iter.next().toBytes();
                success = true;
            } else {
                break;
            }
            ++idx;
        }
        require(success, "rlp decode failed");

        iter = packBytes.toRLPItem().iterator();
        uint8 eventType = uint8(iter.next().toUint());
        RLPDecode.Iterator memory paramIter;
        if (iter.hasNext()) {
            paramIter = iter.next().toBytes().toRLPItem().iterator();
        } else {
            revert("empty ack package");
        }

        if (eventType == EVENT_SEND) {
            bytes32 pkgHash = keccak256(abi.encodePacked(channelId, sequence));
            _handleSendAckPackage(pkgHash, paramIter);
        } else {
            revert("unknown event type");
        }
    }

    function handleFailAckPackage(uint8 channelId, uint256 sequence, bytes calldata msgBytes) external onlyCrossChain {
        RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
        uint8 eventType = uint8(iter.next().toUint());
        RLPDecode.Iterator memory paramIter;
        if (iter.hasNext()) {
            paramIter = iter.next().toBytes().toRLPItem().iterator();
        } else {
            revert("empty fail ack package");
        }
        if (eventType == EVENT_SEND) {
            bytes32 pkgHash = keccak256(abi.encodePacked(channelId, sequence));
            _handleSendFailAckPackage(pkgHash, paramIter);
        } else {
            revert("unknown event type");
        }
    }

    /*----------------- Internal functions -----------------*/
    function _RLPEncode(uint8 eventType, bytes memory msgBytes) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](2);
        elements[0] = eventType.encodeUint();
        elements[1] = msgBytes.encodeBytes();
        return elements.encodeList();
    }

    function _handleSendAckPackage(bytes32 pkgHash, RLPDecode.Iterator memory paramIter) internal {
        bool success;
        uint256 idx;

        address _appAddress;
        address _refundAddress;
        FailureHandleStrategy _strategy;
        bytes memory _appMsg;

        while (paramIter.hasNext()) {
            if (idx == 0) {
                _appAddress = address(uint160(paramIter.next().toAddress()));
            } else if (idx == 1) {
                _refundAddress = address(uint160(paramIter.next().toAddress()));
            } else if (idx == 2) {
                _strategy = FailureHandleStrategy(uint8(paramIter.next().toUint()));
            } else if (idx == 3) {
                _appMsg = paramIter.next().toBytes();
                success = true;
            } else {
                break;
            }
            ++idx;
        }
        require(success, "rlp decode failed");

        uint256 refundFee = CALLBACK_GAS_LIMIT * callBackGasPrice;
        if (_strategy != FailureHandleStrategy.NoCallBack) {
            uint256 gasBefore = gasleft();
            try IApplication(_appAddress).handleAckPackage{gas: CALLBACK_GAS_LIMIT}(channelId, _appMsg, "") {}
            catch (bytes memory reason) {
                if (_strategy != FailureHandleStrategy.Skip) {
                    packageMap[pkgHash] = RetryPackage(_appAddress, _appMsg, "", false, reason);
                    retryQueue[_appAddress].pushBack(pkgHash);
                }
            }

            uint256 gasUsed = gasBefore - gasleft();
            refundFee = (CALLBACK_GAS_LIMIT - gasUsed) * callBackGasPrice;
        }

        // refund
        (success,) = _refundAddress.call{gas: transferGas, value: refundFee}("");
        require(success, "refund failed");
    }

    function _handleSendFailAckPackage(bytes32 pkgHash, RLPDecode.Iterator memory paramIter) internal {
        bool success;
        uint256 idx;

        address _appAddress;
        address _refundAddress;
        FailureHandleStrategy _strategy;
        bytes memory _appMsg;

        while (paramIter.hasNext()) {
            if (idx == 0) {
                _appAddress = address(uint160(paramIter.next().toAddress()));
            } else if (idx == 1) {
                _refundAddress = address(uint160(paramIter.next().toAddress()));
            } else if (idx == 2) {
                _strategy = FailureHandleStrategy(uint8(paramIter.next().toUint()));
            } else if (idx == 3) {
                _appMsg = paramIter.next().toBytes();
                success = true;
            } else {
                break;
            }
            ++idx;
        }
        require(success, "rlp decode failed");

        uint256 refundFee = CALLBACK_GAS_LIMIT * callBackGasPrice;
        if (_strategy != FailureHandleStrategy.NoCallBack) {
            uint256 gasBefore = gasleft();
            try IApplication(_appAddress).handleAckPackage{gas: CALLBACK_GAS_LIMIT}(channelId, _appMsg, "") {}
            catch (bytes memory reason) {
                if (_strategy != FailureHandleStrategy.Skip) {
                    packageMap[pkgHash] = RetryPackage(_appAddress, _appMsg, "", false, reason);
                    retryQueue[_appAddress].pushBack(pkgHash);
                }
            }

            uint256 gasUsed = gasBefore - gasleft();
            refundFee = (CALLBACK_GAS_LIMIT - gasUsed) * callBackGasPrice;
        }

        // refund
        (success,) = _refundAddress.call{gas: transferGas, value: refundFee}("");
        require(success, "refund failed");
    }
}
