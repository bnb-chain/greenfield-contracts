// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

interface IApplication {
    function handleAckPackage(uint8 channelId, bytes calldata msgBytes, bytes calldata callbackData) external;

    function handleFailAckPackage(uint8 channelId, bytes calldata msgBytes, bytes calldata callbackData) external;
}
