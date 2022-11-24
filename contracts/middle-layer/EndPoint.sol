pragma solidity ^0.8.0;


import "@openzeppelin/contracts-upgradeable/utils/structs/DoubleEndedQueueUpgradeable.sol";
import "../CrossChain.sol";
import "../lib/RLPEncode.sol";
import "../lib/RLPDecode.sol";
import "../Config.sol";



interface IApplication {
    function handleAckPackage(uint8 channelID, bytes middleMsg, bytes calldata appMsg) external;
    function handleFailAckPackage(uint8 channelID, bytes middleMsg, bytes calldata appMsg) external;
}

interface ICrossChain {
    function encodeSynMessage(uint8 eventType, uint8 failureHandling, address receiver, uint256 gasLimit, address refundAddress, bytes memory appMsg) external returns (bytes memory synMessage);
    function sendSynPackage(uint8 channelId, bytes calldata msgBytes, uint256 relayFee) external;

    function cachePackage(uint8 channelId, uint256 sequence, byte32 msgHash, address receiver) external;
    function retryPackage(uint8 channelId,  address receiver, bytes msg) external;
    function skipPackage(uint8 channelId,  uint256 sequence) external;
}

contract EndPoint is Config {
    using RLPEncode for *;
    using RLPDecode for *;
    using DoubleEndedQueueUpgradeable for DoubleEndedQueueUpgradeable.Bytes32Deque;

    uint8 public constant EVENT_SEND = 0x01;
    uint256 public constant TEN_DECIMALS = 1e10;

    address public crosschainContract;
    uint256 public toBFSRelayerFee;
    uint256 public callbackGasprice;
    uint256 public transferGas;

    // app address => FailureHandleStrategy
    mapping(address => FailureHandleStrategy) public failureHandleMap;
    // app address => retry queue of package hash
    mapping(address => DoubleEndedQueueUpgradeable.Bytes32Deque) private retryQueue;
    // app retry package hash => retry package
    mapping(bytes32 => RetryPackage) public packageMap;

    enum FailureHandleStrategy {
        Closed,  // using for pausing
        HandleInOrder,
        Skip,
        Cache
    }

    struct RetryPackage {
        address appAddress;
        bytes appMsg;
        bool isFailAck;
    }

    modifier onlyCrossChainContract() {
        require(msg.sender == crosschainContract, "only cross chain contract");
        _;
    }

    function setFailureHandleStrategy(FailureHandleStrategy _strategy) external {
        failureHandleMap[msg.sender] = _strategy;
    }

    // @notice send a cross-chain application message to BFS
    // @param _appPayload - a custom bytes payload to send to the destination contract
    // @param _refundAddress - if the source transaction is cheaper than the amount of value passed, refund the additional amount to this address
    function send(bytes calldata _appMsg, address payable _refundAddress, uint256 _maxGasLimit) external payable {
        address _appAddress = msg.sender;
        require(failureHandleMap[_appAddress] != FailureHandleStrategy.Closed, "application closed");

        // msg.value is the max fee for the whole cross chain txs including app callback
        // check if msg.value is enough for toBFSRelayerFee + _maxGasLimit * gasPrice
        require(msg.value >= toBFSRelayerFee + callbackGasprice * _maxGasLimit, "not enough relay fee");
        uint256 _callbackFee = msg.value - callbackGasprice * _maxGasLimit;

        (bool success,) = _refundAddress.call{gas: transferGas}("");
        require(success, "invalid refundAddress"); // the _refundAddress must be payable


        bytes[] memory elements = new bytes[](5);
        elements[0] = _appAddress.encodeAddress();
        elements[1] = _refundAddress.encodeAddress();
        elements[2] = _callbackFee.encodeUint();
        elements[3] = _maxGasLimit.encodeUint();
        elements[4] = uint8(failureHandleMap[_appAddress]).encodeUint();
        elements[5] = _appMsg.encodeBytes();

        bytes memory msgBytes = _RLPEncode(EVENT_SEND, elements.encodeList());
        ICrossChain(CrossChain).sendSynPackage(APP_CHANNELID, msgBytes, toBFSRelayerFee);
    }

    function retryPackage(address _dstAddress) external payable {

    }

    function skipPackage(address _dstAddress, uint256 _sequence) external payable {

    }

    // @notice receive a payload from ack package
    // @param _appAddress - the application address
    // @param _gasLimit - the gas limit for external contract execution
    // @param _payload - verified payload to send to the destination contract
    function _receiveMessage(address _appAddress, uint256 _maxGasLimit, address _refundAddress, bytes calldata _appMsg, bytes calldata _middleMsg, uint256 _remainingFee) internal {


        // TODO
        // refund
    }

    // receive
    function handleAckPackage(uint8 channelId, uint256 sequence, bytes calldata msgBytes) external onlyCrossChain {
        // TODO

        // decode msgBytes => bytes middleMsg, bytes calldata appMsg
        bytes memory middleMsg;
        bytes memory appMsg;

        // middleMsg => FailureHandleStrategy failureHandle, address _appAddress, uint256 _maxGasLimit, address _refundAddress, bytes calldata _appMsg, bytes calldata _middleMsg, uint256 _remainingFee
        FailureHandleStrategy failureHandle;
        address _appAddress;
        uint256 _maxGasLimit;
        address _refundAddress;
        bytes memory _appMsg;
        bytes memory _middleMsg;
        uint256 _remainingFee;

        _receiveMessage(_appAddress, _maxGasLimit, _refundAddress, _appMsg, _middleMsg, _remainingFee);
    }

    function handleFailAckPackage(uint8 channelId, uint256 sequence, bytes calldata msgBytes) external onlyCrossChain {
        // decode msgBytes => bytes middleMsg, bytes calldata appMsg
        // appMsg => _srcAddress, _dstAddress, _restFee, _appPayload
        // IApplication(_dstAddress).handleFailAckPackage(uint8 channelID, bytes middleMsg, bytes calldata appMsg);

        // 1. HandleInOrder

        // 2. Skip

        // 3. Cache
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
            _handleSendAckPackage(pkgHash, paramIter, status, errCode);
        } else {
            revert("unknown event type");
        }
    }



    /***************************** Internal functions *****************************/
    function _RLPEncode(uint8 eventType, bytes memory msgBytes) internal pure returns(bytes memory output) {
        bytes[] memory elements = new bytes[](2);
        elements[0] = eventType.encodeUint();
        elements[1] = msgBytes.encodeBytes();
        output = elements.encodeList();
    }

    /************************* Handle cross-chain package *************************/
    function _handleSendAckPackage(bytes32 pkgHash, RLPDecode.Iterator memory paramIter, uint8 status, uint8 errCode) internal {
        bool success;
        uint256 idx;

        address _appAddress;
        address _refundAddress;
        uint256 _callbackFee;
        uint256 _maxGasLimit;
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
                _maxGasLimit = uint256(paramIter.next().toUint());
            } else if (idx == 4) {
                _strategy = uint8(paramIter.next().toUint());
            } else if (idx == 5) {
                _appMsg = uint256(paramIter.next().toBytes());
                success = true;
            } else {
                break;
            }
            ++idx;
        }
        require(success, "rlp decode failed");

        uint256 gasBefore = gasleft();
        try IApplication(_appAddress).handleAckPackage{ gas: _maxGasLimit }(APP_CHANNELID, _appMsg) {
        } catch (bytes memory reason) {
            packageMap[pkgHash] = RetryPackage(_appAddress, _appMsg, false);
            retryQueue.pushBack(pkgHash);
        }

        uint256 gasUsed = gasleft() - gasBefore;
        uint256 refundFee = _callbackFee - gasUsed * callbackGasprice;

        // refund
        (bool success,) = _refundAddress.call{ gas: transferGas, value: refundFee }("");
    }
}
