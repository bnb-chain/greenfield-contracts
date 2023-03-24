// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "../middle-layer/NFTWrapResourceStorage.sol";

interface IGroupHub {
    function createGroup(address, string memory, uint256, NFTWrapResourceStorage.ExtraData memory)
        external
        payable
        returns (bool);
    function createGroup(address, string memory) external payable returns (bool);
    function deleteGroup(uint256) external payable returns (bool);
    function deleteGroup(uint256, uint256, NFTWrapResourceStorage.ExtraData memory) external payable returns (bool);
    function updateGroup(
        NFTWrapResourceStorage.UpdateGroupSynPackage memory,
        uint256,
        NFTWrapResourceStorage.UpdateGroupSynPackage memory
    ) external payable returns (bool);
    function updateGroup(NFTWrapResourceStorage.UpdateGroupSynPackage memory) external payable returns (bool);
    function hasRole(bytes32 role, address granter, address account) external view returns (bool);
    function grant(address, uint32, uint256) external;
    function revoke(address, uint32) external;
    function retryPackage() external;
    function skipPackage() external;
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
