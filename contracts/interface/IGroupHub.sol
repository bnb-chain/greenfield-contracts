// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "../middle-layer/resource-mirror/storage/GroupStorage.sol";

interface IGroupHub {
    function createGroup(address creator, string memory name) external payable returns (bool);

    function createGroup(
        address creator,
        string memory name,
        uint256 callbackGasLimit,
        CmnStorage.ExtraData memory extraData
    ) external payable returns (bool);

    function deleteGroup(uint256 tokenId) external payable returns (bool);

    function deleteGroup(
        uint256 tokenId,
        uint256 callbackGasLimit,
        CmnStorage.ExtraData memory extraData
    ) external payable returns (bool);

    function updateGroup(GroupStorage.UpdateGroupSynPackage memory extraData) external payable returns (bool);

    function updateGroup(
        GroupStorage.UpdateGroupSynPackage memory createPackage,
        uint256 callbackGasLimit,
        CmnStorage.ExtraData memory extraData
    ) external payable returns (bool);

    function prepareCreateGroup(
        address sender,
        address owner,
        string memory name
    ) external payable returns (uint8, bytes memory, uint256, uint256, address);

    function prepareDeleteGroup(
        address sender,
        uint256 id
    ) external payable returns (uint8, bytes memory, uint256, uint256, address);

    function prepareUpdateGroup(
        address sender,
        GroupStorage.UpdateGroupSynPackage memory synPkg
    ) external payable returns (uint8, bytes memory, uint256, uint256, address);
}
