// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "../middle-layer/resource-mirror/storage/PermissionStorage.sol";

interface IPermissionHub {
    function deletePolicy(uint256 id) external payable returns (bool);

    function deletePolicy(uint256 id, PermissionStorage.ExtraData memory _extraData) external payable returns (bool);

    function createPolicy(
        bytes calldata _data,
        PermissionStorage.ExtraData memory _extraData
    ) external payable returns (bool);

    function createPolicy(bytes calldata _data) external payable returns (bool);

    function prepareCreatePolicy(
        address,
        bytes calldata
    ) external payable returns (uint8, bytes memory, uint256, uint256, address);

    function prepareCreatePolicy(
        address,
        bytes calldata,
        PermissionStorage.ExtraData memory
    ) external payable returns (uint8, bytes memory, uint256, uint256, address);

    function prepareDeletePolicy(
        address,
        uint256
    ) external payable returns (uint8, bytes memory, uint256, uint256, address);

    function prepareDeletePolicy(
        address,
        uint256,
        PermissionStorage.ExtraData memory
    ) external payable returns (uint8, bytes memory, uint256, uint256, address);
}
