pragma solidity ^0.8.0;

interface IApplication {
    function handleAckPackage(uint8 channelId, bytes calldata msgBytes, bytes calldata callBackData) external;

    function handleFailAckPackage(uint8 channelId, bytes calldata msgBytes, bytes calldata callBackData) external;
}
