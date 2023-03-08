pragma solidity ^0.8.0;

interface ICrossChain {
    function sendSynPackage(uint8 channelId, bytes calldata msgBytes, uint256 relayFee, uint256 ackRelayFee) external;
}
