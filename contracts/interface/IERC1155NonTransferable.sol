pragma solidity ^0.8.0;

interface IERC1155NonTransferable {
    function balanceOf(address owner) external view returns (uint256 balance);

    function mint(address to, uint256 id, uint256 value, bytes memory data) external;

    function mintBatch(address to, uint256[] memory ids, uint256[] memory values, bytes memory data) external;

    function burn(address owner, uint256 id, uint256 value) external;

    function burnBatch(address owner, uint256[] memory ids, uint256[] memory values) external;
}
