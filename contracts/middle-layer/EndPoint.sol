pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/structs/DoubleEndedQueueUpgradeable.sol";
import "../CrossChain.sol";
import "../lib/RLPEncode.sol";
import "../lib/RLPDecode.sol";
import "../Config.sol";

interface IApplication {
    function handleAckPackage(uint8 channelID, bytes calldata appMsg) external;
    function handleFailAckPackage(uint8 channelID, bytes calldata appMsg) external;
}

interface ICrossChain {
    function sendSynPackage(uint8 channelId, bytes calldata msgBytes, uint256 relayFee) external;
}

contract EndPoint is Config {
    using RLPEncode for *;
    using RLPDecode for *;
    using DoubleEndedQueueUpgradeable for DoubleEndedQueueUpgradeable.Bytes32Deque;

    uint8 public constant EVENT_SEND = 0x01;

    address public crossChainContract;
    uint256 public toBFSRelayerFee;
    uint256 public callbackGasPrice;
    uint256 public transferGas;

    // app address => FailureHandleStrategy
    mapping(address => FailureHandleStrategy) public failureHandleMap;
    // app address => retry queue of package hash
    mapping(address => DoubleEndedQueueUpgradeable.Bytes32Deque) private retryQueue;
    // app retry package hash => retry package
    mapping(bytes32 => RetryPackage) public packageMap;

    enum FailureHandleStrategy {
        Closed, // using for pausing
        HandleInOrder,
        Skip,
        Cache
    }

    struct RetryPackage {
        address appAddress;
        bytes appMsg;
        bool isFailAck;
        bytes failReason;
    }

    modifier onlyCrossChain() {
        require(msg.sender == crossChainContract, "only cross chain contract");
        _;
    }

    modifier onlyPackageNotDeleted(bytes32 pkgHash) {
        require(packageMap[pkgHash].appAddress != address(0), "package already deleted");
        _;
    }

    modifier checkFailureStrategy(bytes32 pkgHash) {
        address appAddress = msg.sender;
        require(failureHandleMap[appAddress] != FailureHandleStrategy.Closed, "strategy not allowed");
        require(packageMap[pkgHash].appAddress == appAddress, "invalid caller");
        if (failureHandleMap[appAddress] == FailureHandleStrategy.HandleInOrder) {
            require(retryQueue[appAddress].popFront() == pkgHash, "package not on front");
        }
        _;
    }

    function setFailureHandleStrategy(FailureHandleStrategy _strategy) external {
        failureHandleMap[msg.sender] = _strategy;
    }

    // @notice send a cross-chain application message to BFS
    // @param _appPayload - a custom bytes payload to send to the destination contract
    // @param _refundAddress - if the source transaction is cheaper than the amount of value passed, refund the additional amount to this address
    function send(bytes calldata _appMsg, address payable _refundAddress, uint256 _gasLimit) external payable {
        address _appAddress = msg.sender;
        require(failureHandleMap[_appAddress] != FailureHandleStrategy.Closed, "application closed");

        // msg.value is the max fee for the whole cross chain txs including app callback
        // check if msg.value is enough for toBFSRelayerFee + _gasLimit * gasPrice
        require(msg.value >= toBFSRelayerFee + callbackGasPrice * _gasLimit, "not enough relay fee");
        uint256 _callbackFee = msg.value - callbackGasPrice * _gasLimit;

        (bool success,) = _refundAddress.call{gas: transferGas}("");
        require(success, "invalid refundAddress"); // the _refundAddress must be payable

        bytes[] memory elements = new bytes[](5);
        elements[0] = _appAddress.encodeAddress();
        elements[1] = _refundAddress.encodeAddress();
        elements[2] = _callbackFee.encodeUint();
        elements[3] = _gasLimit.encodeUint();
        elements[4] = uint8(failureHandleMap[_appAddress]).encodeUint();
        elements[5] = _appMsg.encodeBytes();

        bytes memory msgBytes = _RLPEncode(EVENT_SEND, elements.encodeList());
        ICrossChain(crossChainContract).sendSynPackage(APP_CHANNELID, msgBytes, toBFSRelayerFee);
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

    function retryPackage(bytes32 pkgHash) external onlyPackageNotDeleted(pkgHash) checkFailureStrategy(pkgHash) {
        address appAddress = msg.sender;
        bytes memory _appMsg = packageMap[pkgHash].appMsg;
        if (packageMap[pkgHash].isFailAck) {
            IApplication(appAddress).handleFailAckPackage(APP_CHANNELID, _appMsg);
        } else {
            IApplication(appAddress).handleAckPackage(APP_CHANNELID, _appMsg);
        }
        delete packageMap[pkgHash];
        _cleanQueue(appAddress);
    }

    function skipPackage(bytes32 pkgHash) external onlyPackageNotDeleted(pkgHash) checkFailureStrategy(pkgHash) {
        delete packageMap[pkgHash];
        _cleanQueue(msg.sender);
    }

    /**
     * Internal functions ****************************
     */
    function _cleanQueue(address appAddress) internal {
        DoubleEndedQueueUpgradeable.Bytes32Deque storage _queue = retryQueue[appAddress];
        bytes32 _front;
        while (!_queue.empty()) {
            _front = _queue.front();
            if (packageMap[_front].appAddress != address(0)) {
                break;
            }
            _queue.popFront();
        }
    }

    function _RLPEncode(uint8 eventType, bytes memory msgBytes) internal pure returns (bytes memory output) {
        bytes[] memory elements = new bytes[](2);
        elements[0] = eventType.encodeUint();
        elements[1] = msgBytes.encodeBytes();
        output = elements.encodeList();
    }

    /**
     * Handle cross-chain package ************************
     */
    function _handleSendAckPackage(bytes32 pkgHash, RLPDecode.Iterator memory paramIter) internal {
        bool success;
        uint256 idx;

        address _appAddress;
        address _refundAddress;
        uint256 _callbackFee;
        uint256 _gasLimit;
        FailureHandleStrategy _strategy;
        bytes memory _appMsg;

        while (paramIter.hasNext()) {
            if (idx == 0) {
                _appAddress = address(uint160(paramIter.next().toAddress()));
            } else if (idx == 1) {
                _refundAddress = address(uint160(paramIter.next().toAddress()));
            } else if (idx == 2) {
                _callbackFee = uint256(paramIter.next().toUint());
            } else if (idx == 3) {
                _gasLimit = uint256(paramIter.next().toUint());
            } else if (idx == 4) {
                _strategy = FailureHandleStrategy(uint8(paramIter.next().toUint()));
            } else if (idx == 5) {
                _appMsg = paramIter.next().toBytes();
                success = true;
            } else {
                break;
            }
            ++idx;
        }
        require(success, "rlp decode failed");

        uint256 gasBefore = gasleft();
        try IApplication(_appAddress).handleAckPackage{gas: _gasLimit}(APP_CHANNELID, _appMsg) {}
        catch (bytes memory reason) {
            if (_strategy != FailureHandleStrategy.Skip) {
                packageMap[pkgHash] = RetryPackage(_appAddress, _appMsg, false, reason);
                retryQueue[_appAddress].pushBack(pkgHash);
            }
        }

        uint256 gasUsed = gasleft() - gasBefore;
        uint256 refundFee = _callbackFee - gasUsed * callbackGasPrice;

        // refund
        (success,) = _refundAddress.call{gas: transferGas, value: refundFee}("");
    }

    function _handleSendFailAckPackage(bytes32 pkgHash, RLPDecode.Iterator memory paramIter) internal {
        bool success;
        uint256 idx;

        address _appAddress;
        address _refundAddress;
        uint256 _callbackFee;
        uint256 _gasLimit;
        FailureHandleStrategy _strategy;
        bytes memory _appMsg;

        while (paramIter.hasNext()) {
            if (idx == 0) {
                _appAddress = address(uint160(paramIter.next().toAddress()));
            } else if (idx == 1) {
                _refundAddress = address(uint160(paramIter.next().toAddress()));
            } else if (idx == 2) {
                _callbackFee = uint256(paramIter.next().toUint());
            } else if (idx == 3) {
                _gasLimit = uint256(paramIter.next().toUint());
            } else if (idx == 4) {
                _strategy = FailureHandleStrategy(uint8(paramIter.next().toUint()));
            } else if (idx == 5) {
                _appMsg = paramIter.next().toBytes();
                success = true;
            } else {
                break;
            }
            ++idx;
        }
        require(success, "rlp decode failed");

        uint256 gasBefore = gasleft();
        try IApplication(_appAddress).handleFailAckPackage{gas: _gasLimit}(APP_CHANNELID, _appMsg) {}
        catch (bytes memory reason) {
            if (_strategy != FailureHandleStrategy.Skip) {
                packageMap[pkgHash] = RetryPackage(_appAddress, _appMsg, true, reason);
                retryQueue[_appAddress].pushBack(pkgHash);
            }
        }
        uint256 gasUsed = gasleft() - gasBefore;
        uint256 refundFee = _callbackFee - gasUsed * callbackGasPrice;

        // refund
        (success,) = _refundAddress.call{gas: transferGas, value: refundFee}("");
    }
}
