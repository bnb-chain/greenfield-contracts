pragma solidity ^0.8.0;

interface IMiddleLayer {
    /**
     * @dev Handle syn package
     */
    function handleSynPackage(uint8 channelId, bytes calldata msgBytes)
        external
        returns (bytes memory responsePayload);

    /**
     * @dev Handle ack package
     */
    function handleAckPackage(uint8 channelId, uint64 sequence, bytes calldata msgBytes, uint256 callbackGasLimit)
        external
        returns (uint256 remainingGas, address refundAddress);

    /**
     * @dev Handle fail ack package
     */
    function handleFailAckPackage(uint8 channelId, uint64 sequence, bytes calldata msgBytes, uint256 callbackGasLimit)
        external
        returns (uint256 remainingGas, address refundAddress);

    function minAckRelayFee() external returns (uint256);
}
