pragma solidity ^0.8.0;

interface ILightClient {
    function verifyPackage(bytes calldata _payload, bytes calldata _blsSignature, uint256 _validatorSet) external view;
    function getRelayers() external view returns(address[] memory);
}
