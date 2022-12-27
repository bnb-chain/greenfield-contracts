pragma solidity ^0.8.0;

contract InscriptionLightClient {
    /* --------------------- 1. constant --------------------- */
    address constant public LIGHT_CLIENT_CONTRACT = 0x0000000000000000000000000000000000003000;
    uint256 constant public BLS_PUBKEY_LENGTH = 48;

    uint8 constant public PREFIX_VERIFY_HEADER = 0x01;
    uint8 constant public PREFIX_VERIFY_PACKAGE = 0x02;
    /* --------------------- 2. storage --------------------- */
    uint64 public height;
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
        require(_relayers.length == _blsPubKeys.length / BLS_PUBKEY_LENGTH, "length mismatch between _relayers and _blsPubKeys");
        require(_height > height, "invalid block height");

        // verify blsSignature and decode block header
        bytes memory input = abi.encodePacked(PREFIX_VERIFY_HEADER, _header, _height, _blsPubKeys, _relayers);
        (bool success, ) = LIGHT_CLIENT_CONTRACT.staticcall(input);
        require(success, "invalid header");

        // validators changed
        if (_blsPubKeys.length > 0) {
            // update new validators info
            blsPubKeys = _blsPubKeys;
            relayers = _relayers;
        }

        height = _height;
    }

    function verifyPackage(
        bytes memory _pkgKey,
        bytes calldata _payload,
        bytes calldata _blsSignature,
        uint256 _validatorSet
    ) external view {
        bytes memory input = abi.encodePacked(PREFIX_VERIFY_PACKAGE, _pkgKey, _payload, _blsSignature, _validatorSet, blsPubKeys);
        (bool success, bytes memory data) = LIGHT_CLIENT_CONTRACT.staticcall(input);
        require(success && data.length > 0, "invalid cross-chain package");
    }

    function getRelayers() external view returns(address[] memory) {
        return relayers;
    }
}
