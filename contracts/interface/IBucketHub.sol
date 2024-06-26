// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "../middle-layer/resource-mirror/storage/BucketStorage.sol";

interface IBucketHub {
    function createBucket(BucketStorage.CreateBucketSynPackage memory createPackage) external payable returns (bool);

    function createBucket(
        BucketStorage.CreateBucketSynPackage memory createPackage,
        uint256 callbackGasLimit,
        CmnStorage.ExtraData memory extraData
    ) external payable returns (bool);

    function deleteBucket(uint256 tokenId) external payable returns (bool);

    function deleteBucket(
        uint256 tokenId,
        uint256 callbackGasLimit,
        CmnStorage.ExtraData memory extraData
    ) external payable returns (bool);

    function prepareCreateBucket(
        address,
        BucketStorage.CreateBucketSynPackage memory
    ) external payable returns (uint8, bytes memory, uint256, uint256, address);

    function prepareCreateBucket(
        address,
        BucketStorage.CreateBucketSynPackage memory,
        uint256,
        CmnStorage.ExtraData memory
    ) external payable returns (uint8, bytes memory, uint256, uint256, address);

    function prepareDeleteBucket(
        address,
        uint256
    ) external payable returns (uint8, bytes memory, uint256, uint256, address);

    function prepareDeleteBucket(
        address,
        uint256,
        uint256,
        CmnStorage.ExtraData memory
    ) external payable returns (uint8, bytes memory, uint256, uint256, address);
}
