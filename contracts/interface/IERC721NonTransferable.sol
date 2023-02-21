pragma solidity ^0.8.0;

interface IERC721NonTransferable {
    function balanceOf(address owner) external view returns (uint256 balance);

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function mint(address to, uint256 tokenId) external;

    function burn(uint256 tokenId) external;

    function setBaseURI(string calldata newURI) external;
}
