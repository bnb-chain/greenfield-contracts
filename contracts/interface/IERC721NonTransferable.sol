// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

/**
 * @dev External interface of ERC721NonTransferable declared to support ERC165 detection.
 *
 * This Non-Fungible Token doesn't support token transfer or approval.
 */
interface IERC721NonTransferable {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function balanceOf(address owner) external view returns (uint256 balance);

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function exists(uint256 tokenId) external view returns (bool);

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function setBaseURI(string calldata newURI) external;

    function mint(address to, uint256 tokenId) external;

    function burn(uint256 tokenId) external;

    function getApproved(uint256 tokenId) external view returns (address operator);

    function isApprovedForAll(address owner, address operator) external view returns (bool);

    function totalSupply() external view returns (uint256);

    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    function tokenByIndex(uint256 index) external view returns (uint256);
}
