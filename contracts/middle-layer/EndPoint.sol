pragma solidity =0.8.17;
import "../CrossChain.sol";

interface IApplication {
    function handleAckPackage(uint8 channelID, bytes middleMsg, bytes calldata appMsg) external;
    function handleFailAckPackage(uint8 channelID, bytes middleMsg, bytes calldata appMsg) external;
}

interface ICrossChain {
    function sendSynPackage(uint8 channelId, bytes calldata msgBytes, uint256 relayFee) external;

    function cachePackage(uint8 channelId, uint256 sequence, byte32 msgHash, address receiver) external;
    function retryPackage(uint8 channelId,  address receiver, bytes msg) external;
    function skipPackage(uint8 channelId,  uint256 sequence) external;
}

contract EndPoint {
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
    // @param _dstAddress - call the destination application address while received crosschain ack package
    // @param _appPayload - a custom bytes payload to send to the destination contract
    // @param _refundAddress - if the source transaction is cheaper than the amount of value passed, refund the additional amount to this address
    function send(address _dstAddress, bytes calldata _appPayload, address payable _refundAddress) external payable {
        require(failureHandleMap[msg.sender] != FailureHandleStrategy.Closed, "application closed");

        // msg.value is the max fee for the whole cross chain txs including app callback
        // msg.sender, msg.value, _destination, _appPayload, _refundAddress => appBytes

        // ICrossChain(CrossChain).sendSynPackage(uint8 channelId, bytes calldata msgBytes, uint256 relayFee)
    }

    function retryPayload(address _dstAddress, address payable _refundAddress) external payable {

    }

    function retryPackage(address _dstAddress) external payable {

    }

    function skipPackage(address _dstAddress, uint256 _sequence) external payable {

    }

    // @notice receive a payload from ack package
    // @param _srcAddress - the source contract (as bytes) at the source chain
    // @param _dstAddress - the address on destination chain
    // @param _gasLimit - the gas limit for external contract execution
    // @param _payload - verified payload to send to the destination contract
    function _receivePayload(address _srcAddress, address _dstAddress, uint256 _remainingFee, bytes calldata _appPayload) internal {
        // _remainingFee => _gasLimit
        uint256 _gasLimit;

        // from handleAckPackage
        try IApplication(_dstAddress).handleAckPackage{gas: _gasLimit}(_srcChainId, _srcAddress, _nonce, _payload) {

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
        // appMsg => _srcAddress, _dstAddress, _restFee, _appPayload
        // receivePayload(address _srcAddress, address _dstAddress, uint256 _remainingFee, bytes calldata _appPayload)
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
