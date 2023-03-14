// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

interface ICrossChain {
    function sendSynPackage(uint8 channelId, bytes calldata msgBytes, uint256 relayFee, uint256 ackRelayFee) external;
    function getRelayFees() external returns (uint256 relayFee, uint256 minAckRelayFee);
}
