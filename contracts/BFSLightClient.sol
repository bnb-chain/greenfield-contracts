pragma solidity ^0.8.0;

contract BFSLightClient {

    /* --------------------- 1. constant --------------------- */

    /* --------------------- 2. storage --------------------- */
    uint64 public height;
    bytes32 public appHash;
    ValidatorInfo[] public validatorSet;

    struct ValidatorInfo {
        address validator;
        address relayer;
        bytes32 blsPublicKey;
    }


}
