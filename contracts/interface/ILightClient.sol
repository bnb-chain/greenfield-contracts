// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

interface ILightClient {
    struct InturnRelayer {
        address addr;
        bytes blsKey;
        uint256 start;
        uint256 end;
    }

    function verifyPackage(bytes calldata _payload, bytes calldata _blsSignature, uint256 _validatorSet)
        external
        view
        returns (bool verified);
    function getRelayers() external view returns (address[] memory);
    function getInturnRelayer() external view returns (InturnRelayer memory);
    function getInturnRelayerAddress() external view returns (address);
}
