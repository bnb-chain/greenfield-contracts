// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

interface ICrossChain {
    function sendSynPackage(uint8 channelId, bytes calldata msgBytes, uint256 relayFee, uint256 ackRelayFee) external;

    function getRelayFees() external view returns (uint256 relayFee, uint256 minAckRelayFee);

    function callbackGasPrice() external returns (uint256);

    function handleAckPackageFromMultiMessage(
        bytes calldata _multiMessagePayload,
        uint8 _packageType,
        uint64 _multiMessageSequence
    ) external;
}
