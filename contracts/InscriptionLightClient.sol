pragma solidity ^0.8.0;

contract InscriptionLightClient {
    /* --------------------- 1. constant --------------------- */
    bytes constant public INIT_CONSENSUS_STATE_BYTES = hex"42696e616e63652d436861696e2d4e696c650000000000000000000000000000000000000000000229eca254b3859bffefaf85f4c95da9fbd26527766b784272789c30ec56b380b6eb96442aaab207bc59978ba3dd477690f5c5872334fc39e627723daa97e441e88ba4515150ec3182bc82593df36f8abb25a619187fcfab7e552b94e64ed2deed000000e8d4a51000";
    address constant public LIGHT_CLIENT_CONTRACT = 0x0000000000000000000000000000000000003000;
    uint256 constant public BLS_PUBKEY_LENGTH = 48;

    uint8 constant public PREFIX_VERIFY_HEADER = 0x01;
    uint8 constant public PREFIX_VERIFY_PACKAGE = 0x02;

    uint256 constant public IN_TURN_RELAYER_VALIDITY_PERIOD = 15 seconds;
    uint256 constant public RELAYER_SUBMIT_PACKAGE_INTERVAL = 3 seconds;

    /* --------------------- 2. storage --------------------- */
    uint64 public height;
    bytes32 curValidatorSetHash;
    address[] public validators;
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
        bytes calldata _payload,
        bytes calldata _blsSignature,
        uint256 _validatorSet,
        bytes memory _pkgKey,
        address _pkgRelayer
    ) external view {
        bytes memory input = abi.encodePacked(PREFIX_VERIFY_PACKAGE, _payload, _blsSignature, _pkgKey, _validatorSet, blsPubKeys);
        (bool success, bytes memory data) = LIGHT_CLIENT_CONTRACT.staticcall(input);
        require(success && data.length > 0, "invalid cross-chain package");
        (uint64 eventTime) = abi.decode(data, (uint64));

        // check if it is the valid relayer
        uint256 _totalRelayers = relayers.length;
        uint256 _currentIndex = uint256(eventTime) % _totalRelayers;
        if (_pkgRelayer != relayers[_currentIndex]) {
            uint256 diffSeconds = block.timestamp - uint256(eventTime);
            require(diffSeconds >= IN_TURN_RELAYER_VALIDITY_PERIOD, "not in turn relayer");

            bool isValidRelayer;
            for (uint256 i; i < _totalRelayers; ++i) {
                _currentIndex = (_currentIndex + 1) % _totalRelayers;
                if (_pkgRelayer == relayers[_currentIndex]) {
                    isValidRelayer = true;
                    break;
                }

                if (diffSeconds < RELAYER_SUBMIT_PACKAGE_INTERVAL) {
                    break;
                }
                diffSeconds -= RELAYER_SUBMIT_PACKAGE_INTERVAL;
            }

            require(isValidRelayer, "invalid candidate relayer");
        }
    }

}
