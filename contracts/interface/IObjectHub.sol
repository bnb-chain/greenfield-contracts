// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "../middle-layer/resource-mirror/storage/ObjectStorage.sol";

interface IObjectHub {
    function deleteObject(uint256 tokenId) external payable returns (bool);

    function deleteObject(
        uint256 tokenId,
        uint256 callbackGasLimit,
        CmnStorage.ExtraData memory extraData
    ) external payable returns (bool);

    function prepareDeleteObject(
        address sender,
        uint256 id
    ) external payable returns (uint8, bytes memory, uint256, uint256, address);

    function prepareDeleteObject(
        address sender,
        uint256 id,
        uint256 callbackGasLimit,
        CmnStorage.ExtraData memory extraData
    ) external payable returns (uint8, bytes memory, uint256, uint256, address);
}
