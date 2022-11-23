pragma solidity ^0.8.0;
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

    uint8 public constant EVENT_SEND = 0x01;

    uint256 public toBFSRelayerFee;
    uint256 public callbackGasprice;
    uint8 public channelId;

    // ua/_dstAddress => FailureHandleStrategy
    mapping(address => FailureHandleStrategy) public failureHandleMap;

    // ua/_dstAddress => StorePayload from executed ack
    mapping(address => StorePayload) public storePayload;

    enum FailureHandleStrategy {
        Closed,  // using for pausing
        HandleInOrder,
        Skip,
        Cache
    }

    struct StorePayload {
        address srcAddress;
        bytes appPayload;
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
        elements[4] = _appMsg.encodeBytes();

        bytes memory msgBytes = _RLPEncode(EVENT_SEND, elements.encodeList());
        ICrossChain(CrossChain).sendSynPackage(APP_CHANNELID, msgBytes, toBFSRelayerFee);
    }

    function retryPayload(address _dstAddress, address payable _refundAddress) external payable {

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
        // from handleAckPackage
        try IApplication(_appAddress).handleAckPackage{ gas: _maxGasLimit }(channelId, _middleMsg, _appMsg) {

        } catch (bytes memory reason) {
            // TODO
            // store Payload to retry
        }

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
}
