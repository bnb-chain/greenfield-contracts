// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "../middle-layer/NFTWrapResourceStorage.sol";

interface IBucketHub {
    function createBucket(
        NFTWrapResourceStorage.CreateBucketSynPackage memory,
        uint256,
        NFTWrapResourceStorage.ExtraData memory
    ) external payable returns (bool);
    function createBucket(NFTWrapResourceStorage.CreateBucketSynPackage memory) external payable returns (bool);
    function deleteBucket(uint256) external payable returns (bool);
    function deleteBucket(uint256, uint256, NFTWrapResourceStorage.ExtraData memory) external payable returns (bool);
    function hasRole(bytes32 role, address granter, address account) external view returns (bool);
    function grant(address, uint32, uint256) external;
    function revoke(address, uint32) external;
    function retryPackage() external;
    function skipPackage() external;
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
