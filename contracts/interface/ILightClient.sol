pragma solidity ^0.8.0;

interface ILightClient {
    function verifyPackage(bytes memory _pkgKey, bytes calldata _payload, bytes calldata _blsSignature, uint256 _validatorSet, address _pkgRelayer) external view;
}
