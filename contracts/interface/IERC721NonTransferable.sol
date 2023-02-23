pragma solidity ^0.8.0;

interface IERC721NonTransferable {
    function balanceOf(address owner) external view returns (uint256 balance);

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function exists(uint256 tokenId) external view returns (bool);

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function mint(address to, uint256 tokenId) external;

    function burn(uint256 tokenId) external;

    function setBaseURI(string calldata newURI) external;

    function totalSupply() external view returns (uint256);

    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    function tokenByIndex(uint256 index) external view returns (uint256);
}
