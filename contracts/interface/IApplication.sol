// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "../middle-layer/NFTWrapResourceStorage.sol";

interface IApplication {
    function handleAckPackage(
        uint8 channelId,
        NFTWrapResourceStorage.CmnCreateAckPackage calldata ackPkg,
        bytes calldata callbackData
    ) external;
    function handleAckPackage(
        uint8 channelId,
        NFTWrapResourceStorage.CmnDeleteAckPackage calldata ackPkg,
        bytes calldata callbackData
    ) external;
    function handleAckPackage(
        uint8 channelId,
        NFTWrapResourceStorage.UpdateGroupAckPackage calldata ackPkg,
        bytes calldata callbackData
    ) external;

    function handleFailAckPackage(
        uint8 channelId,
        NFTWrapResourceStorage.CmnDeleteSynPackage calldata deleteSynPkg,
        bytes calldata callbackData
    ) external;
    function handleFailAckPackage(
        uint8 channelId,
        NFTWrapResourceStorage.CreateBucketSynPackage calldata createBucketSynPkg,
        bytes calldata callbackData
    ) external;
    function handleFailAckPackage(
        uint8 channelId,
        NFTWrapResourceStorage.CreateGroupSynPackage calldata createGroupSynPkg,
        bytes calldata callbackData
    ) external;
    function handleFailAckPackage(
        uint8 channelId,
        NFTWrapResourceStorage.UpdateGroupSynPackage calldata updateGroupSynPkg,
        bytes calldata callbackData
    ) external;
}
