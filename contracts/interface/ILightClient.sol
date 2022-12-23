pragma solidity ^0.8.0;

interface ILightClient {
    function verifyPackage(bytes calldata payload, bytes calldata blsSignature, uint256 validatorSet, uint64 packageSequence, uint8 channelId) external view returns (bool);
    function verifyPackageRelayer(address pkgRelayer, uint256 pkgTime) external view returns (bool);
}
