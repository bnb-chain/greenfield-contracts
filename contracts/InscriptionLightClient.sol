pragma solidity ^0.8.0;

import "./Config.sol";

contract InscriptionLightClient is Config {
    /* --------------------- 1. constant --------------------- */
    address constant public LIGHT_CLIENT_CONTRACT = 0x0000000000000000000000000000000000000065;
    address constant public PACKAGE_VERIFY_CONTRACT = 0x0000000000000000000000000000000000000066;
    uint256 constant public BLS_PUBKEY_LENGTH = 48;

    /* --------------------- 2. storage --------------------- */
    uint64 public insHeight;
    address[] public relayers;
    bytes public blsPubKeys;

    modifier onlyRelayer() {
        bool isRelayer;
        uint256 _totalRelayers = relayers.length;
        require(_totalRelayers > 0, "empty relayers");
        for (uint256 i = 0; i < _totalRelayers; i++) {
            if (relayers[i] == msg.sender) {
                isRelayer = true;
                break;
            }
        }
        require(isRelayer, "only relayer");

        _;
    }

    function syncTendermintHeader(
        bytes calldata _header,
        uint64 _height,
        bytes calldata _blsPubKeys,
        address[] calldata _relayers
    ) external onlyRelayer {
        require(_relayers.length * BLS_PUBKEY_LENGTH == _blsPubKeys.length, "length mismatch between _relayers and _blsPubKeys");
        require(_height > insHeight, "invalid block height");

        // verify blsSignature and decode block header
        bytes memory input = abi.encodePacked(_header, _height, _blsPubKeys, _relayers);
        (bool success, bytes memory data) = LIGHT_CLIENT_CONTRACT.staticcall(input);
        require(success && data.length > 0, "invalid header");

        // validators changed
        if (_blsPubKeys.length > 0) {
            // update new validators info
            blsPubKeys = _blsPubKeys;
            relayers = _relayers;
        }

        insHeight = _height;
    }

    function verifyPackage(
        bytes calldata _payload,
        bytes calldata _blsSignature,
        uint256 _validatorSetBitMap
    ) external view {
        bytes32 msgHash = keccak256(_payload);
        bytes memory input = abi.encodePacked(msgHash, _blsSignature, _validatorSetBitMap, blsPubKeys);
        (bool success, bytes memory data) = PACKAGE_VERIFY_CONTRACT.staticcall(input);
        require(success && data.length > 0, "invalid cross-chain package");
    }

    function getRelayers() external view returns(address[] memory) {
        return relayers;
    }
}
