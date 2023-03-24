// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "../middle-layer/resource-mirror/storage/BucketStorage.sol";
import "../middle-layer/resource-mirror/storage/GroupStorage.sol";

interface IApplication {
    function handleAckPackage(
        uint8 channelId,
        CmnStorage.CmnCreateAckPackage calldata ackPkg,
        bytes calldata callbackData
    ) external;

    function handleAckPackage(
        uint8 channelId,
        CmnStorage.CmnDeleteAckPackage calldata ackPkg,
        bytes calldata callbackData
    ) external;

    function handleAckPackage(
        uint8 channelId,
        GroupStorage.UpdateGroupAckPackage calldata ackPkg,
        bytes calldata callbackData
    ) external;

    function handleFailAckPackage(
        uint8 channelId,
        CmnStorage.CmnDeleteSynPackage calldata deleteSynPkg,
        bytes calldata callbackData
    ) external;

    function handleFailAckPackage(
        uint8 channelId,
        BucketStorage.CreateBucketSynPackage calldata createBucketSynPkg,
        bytes calldata callbackData
    ) external;

    function handleFailAckPackage(
        uint8 channelId,
        GroupStorage.CreateGroupSynPackage calldata createGroupSynPkg,
        bytes calldata callbackData
    ) external;

    function handleFailAckPackage(
        uint8 channelId,
        GroupStorage.UpdateGroupSynPackage calldata updateGroupSynPkg,
        bytes calldata callbackData
    ) external;
}
