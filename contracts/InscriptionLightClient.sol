pragma solidity ^0.8.0;

contract InscriptionLightClient {
    /* --------------------- 1. constant --------------------- */
    bytes constant public INIT_CONSENSUS_STATE_BYTES = hex"42696e616e63652d436861696e2d4e696c650000000000000000000000000000000000000000000229eca254b3859bffefaf85f4c95da9fbd26527766b784272789c30ec56b380b6eb96442aaab207bc59978ba3dd477690f5c5872334fc39e627723daa97e441e88ba4515150ec3182bc82593df36f8abb25a619187fcfab7e552b94e64ed2deed000000e8d4a51000";
    address constant public LIGHT_CLIENT_CONTRACT = 0x0000000000000000000000000000000000003000;
    uint256 constant public BLS_PUBKEY_LENGTH = 48;

    /* --------------------- 2. storage --------------------- */
    uint64 public height;
    bytes32 public appHash;
    bytes32 curValidatorSetHash;
    address[] public validators;
    address[] public relayers;
    bytes public blsPubKeys;

    modifier onlyRelayer() {
        bool isRelayer;
        require(relayers.length > 0, "empty relayers");
        for (uint256 i = 0; i < relayers.length; i++) {
            if (relayers[i] == msg.sender) {
                isRelayer = true;
                break;
            }
        }
        require(isRelayer, "invalid relayer");

        _;
    }

    function syncTendermintHeader(
        bytes calldata _headerWithSig,
        address[] calldata _validators,
        address[] calldata _relayers,
        bytes calldata _blsPubKeys
    ) external onlyRelayer {
        require(_validators.length == _relayers.length, "length mismatch between validators and relayers");
        require(_validators.length == _blsPubKeys.length / BLS_PUBKEY_LENGTH, "length mismatch between validators and _blsPubKeys");

        // verify blsSignature and decode block header
        bytes memory input = abi.encodePacked(_headerWithSig, _blsPubKeys);
        (bool success, bytes memory data) = LIGHT_CLIENT_CONTRACT.staticcall(input);
        (uint64 _height, bytes32 _appHash, bytes32 _curValidatorSetHash) = abi.decode(data, (uint64, bytes32, bytes32));
        require(_height > height, "invalid block height");

        if (_validators.length == 0) { // validators not changed
            require(_curValidatorSetHash == curValidatorSetHash, "_curValidatorSetHash changed while validators not changed");
        } else { // validators changed

            // verify _curValidatorSetHash
            require(getValidatorsHash(_validators, _relayers, _blsPubKeys) == _curValidatorSetHash, "validators hash from header mismatch");

            // update new validators info
            validators = _validators;
            relayers = _relayers;
            blsPubKeys = _blsPubKeys;
        }

        height = _height;
        appHash = _appHash;
        curValidatorSetHash = _curValidatorSetHash;
    }

    function getValidatorsHash(
        address[] calldata _validators,
        address[] calldata _relayers,
        bytes calldata _blsPubKeys
    ) internal view returns(bytes32 _hash) {
        // TODO

    }
}
