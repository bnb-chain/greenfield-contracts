pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./Config.sol";
import "./lib/Memory.sol";
import "./lib/BytesToTypes.sol";
import "./lib/BytesLib.sol";
import "hardhat/console.sol";

contract GnfdLightClient is Initializable, Config {
    struct Validator {
        bytes32 pubKey;
        int64 votingPower;
        address relayerAddress;
        bytes relayerBlsKey;
    }

    /* --------------------- 1. constant --------------------- */
    uint256 public constant CHAIN_ID_LENGTH = 32;
    uint256 public constant HEIGHT_LENGTH = 8;
    uint256 public constant VALIDATOR_SET_HASH_LENGTH = 32;
    uint256 public constant CONSENSUS_STATE_BASE_LENGTH = CHAIN_ID_LENGTH + HEIGHT_LENGTH + VALIDATOR_SET_HASH_LENGTH;

    uint256 public constant VALIDATOR_PUB_KEY_LENGTH = 32;
    uint256 public constant VALIDATOR_VOTING_POWER_LENGTH = 8;
    uint256 public constant RELAYER_ADDRESS_LENGTH = 20;
    uint256 public constant RELAYER_BLS_KEY_LENGTH = 48;

    uint256 public constant VALIDATOR_BYTES_LENGTH =
        VALIDATOR_PUB_KEY_LENGTH + VALIDATOR_VOTING_POWER_LENGTH + RELAYER_ADDRESS_LENGTH + RELAYER_BLS_KEY_LENGTH;
    uint256 public constant MESSAGE_HASH_LENGTH = 32;
    uint256 public constant BLS_SIGNATURE_LENGTH = 96;

    /* --------------------- 2. storage --------------------- */
    uint64 public initialHeight;

    bytes32 public chainID;
    uint64 public height;
    bytes32 public nextValidatorSetHash;
    bytes public consensusStateBytes;
    Validator[] public validatorSet;
    mapping(uint64 => address payable) public submitters;

    /* --------------------- 3. events ----------------------- */
    event initConsensusState(uint64 height);
    event updateConsensusState(uint64 height, bool validatorSetChanged);

    /* --------------------- 4. functions -------------------- */
    modifier onlyRelayer() {
        require(validatorSet.length != 0, "empty relayers");

        bool isRelayer;
        for (uint256 i = 0; i < validatorSet.length; i++) {
            if (validatorSet[i].relayerAddress == msg.sender) {
                isRelayer = true;
                break;
            }
        }
        require(isRelayer, "only relayer");

        _;
    }

    function initialize(bytes calldata _initConsensusStateBytes) public initializer {
        uint256 ptr;
        uint256 len;
        bytes32 tmpChainID;

        (ptr, len) = Memory.fromBytes(_initConsensusStateBytes);
        assembly {
            tmpChainID := mload(ptr)
        }

        chainID = tmpChainID;
        decodeConsensusState(ptr, len, true);
        initialHeight = height;
        consensusStateBytes = _initConsensusStateBytes;

        emit initConsensusState(height);
    }

    function syncTendermintHeader(bytes calldata _header, uint64 _height) external onlyRelayer returns (bool) {
        require(submitters[_height] == address(0x0), "can't sync duplicated header");
        require(_height > height, "can't sync header before latest height");

//        uint256 consensusLength = CONSENSUS_STATE_BASE_LENGTH + validatorSet.length * VALIDATOR_BYTES_LENGTH;
//        bytes memory input = new bytes(consensusLength + _header.length);
//        uint256 ptr = Memory.dataPtr(input);
//        uint256 src;
//
//        encodeConsensusState(ptr, consensusLength);
//
//        ptr = ptr + consensusLength;
//        (src,) = Memory.fromBytes(_header);
//        Memory.copy(src, ptr, _header.length);

        bytes memory tmpHeader = _header;
        bytes memory input = BytesLib.concat(consensusStateBytes, tmpHeader);

//        uint256 totalLength = input.length + 32;
//        bytes32[128] memory result; // Maximum validator quantity is 99
//        assembly {
//            // call gnfdLightBlockValidate precompile contract
//            // Contract address: 0x67
//            if iszero(staticcall(not(0), 0x67, input, totalLength, result, 4096)) { revert(0, 0) }
//        }

        address HEADER_VALIDATE_CONTRACT = address(0x0000000000000000000000000000000000000067);
        (bool success, bytes memory result) = HEADER_VALIDATE_CONTRACT.staticcall(input);
        require(success, "header validate failed");

        uint256 ptr;
        assembly {
            ptr := mload(add(result, 0))
        }
        bool validatorSetChanged = false;
        if ((ptr & (0x01 << 248)) != 0x00) {
            validatorSetChanged = true;
        }
        uint256 length = ptr & 0xffffffffffffffff;

        assembly {
            ptr := add(result, 32)
        }
        decodeConsensusState(ptr, length, validatorSetChanged);

        require(height == _height, "invalid header height");
        consensusStateBytes = Memory.toBytes(ptr, length);
        submitters[_height] = payable(msg.sender);

        emit updateConsensusState(_height, validatorSetChanged);

        return true;
    }

    function verifyPackage(bytes calldata _payload, bytes calldata _blsSignature, uint256 _validatorSetBitMap)
        external
        view
    {
        console.log("validatorSet pubkeys");
        for (uint i ; i < validatorSet.length; i++) {
            console.logBytes(validatorSet[i].relayerBlsKey);
        }

        require(_blsSignature.length == BLS_SIGNATURE_LENGTH, "invalid signature length");

        bytes32 msgHash = keccak256(_payload);
        console.log("msgHash");
        console.logBytes32(msgHash);

        bytes memory tmpBlsSig = _blsSignature;
        bytes memory input = BytesLib.concat(abi.encode(msgHash), tmpBlsSig);
        console.log("168 newInput");
        console.logBytes(input);

        uint256 bitCount;
        for (uint256 i = 0; i < validatorSet.length; i++) {
            if ((_validatorSetBitMap & (0x1 << i)) != 0) {
                bitCount++;
                input = BytesLib.concat(input, validatorSet[i].relayerBlsKey);
            }
        }
        require(bitCount >= validatorSet.length*2/3, "no majority validators");

        console.log("183 newInput");
        console.logBytes(input);

        address PACKAGE_VERIFY_CONTRACT = address(0x0000000000000000000000000000000000000066);
        (bool success, bytes memory result) = PACKAGE_VERIFY_CONTRACT.staticcall(input);

        console.log('0x66 ins precompile', success);
        console.logBytes(result);

        require(success && result.length > 0, "invalid cross-chain package");
    }

    function getRelayers() external view returns (address[] memory) {
        address[] memory relayers = new address[](validatorSet.length);
        for (uint256 i = 0; i < validatorSet.length; i++) {
            relayers[i] = validatorSet[i].relayerAddress;
        }
        return relayers;
    }

    // output:
    // | chainID   | height   | nextValidatorSetHash | [{validator pubkey, voting power, relayer address, relayer bls pubkey}] |
    // | 32 bytes  | 8 bytes  | 32 bytes             | [{32 bytes, 8 bytes, 20 bytes, 48 bytes}]                               |
    function encodeConsensusState(uint256 ptr, uint256 size) internal view {
        ptr = ptr + CONSENSUS_STATE_BASE_LENGTH - VALIDATOR_SET_HASH_LENGTH;
        assembly {
            mstore(ptr, sload(nextValidatorSetHash.slot))
        }

        ptr = ptr - 32;
        assembly {
            mstore(ptr, sload(height.slot))
        }

        ptr = ptr + 32 - HEIGHT_LENGTH - CHAIN_ID_LENGTH;
        assembly {
            mstore(ptr, sload(chainID.slot))
        }

        ptr = ptr + CONSENSUS_STATE_BASE_LENGTH;
        for (uint256 i = 0; i < validatorSet.length; i++) {
            encodeValidator(ptr, validatorSet[i]);
            ptr = ptr + VALIDATOR_BYTES_LENGTH;
        }
    }

    function encodeValidator(uint256 ptr, Validator memory val) internal view {
        uint256 src;

        ptr = ptr + VALIDATOR_BYTES_LENGTH - RELAYER_BLS_KEY_LENGTH;
        (src,) = Memory.fromBytes(val.relayerBlsKey);
        Memory.copy(src, ptr, RELAYER_BLS_KEY_LENGTH);

        ptr = ptr - RELAYER_ADDRESS_LENGTH;
        (src,) = Memory.fromBytes(abi.encodePacked(uint160(val.relayerAddress)));
        Memory.copy(src, ptr, RELAYER_ADDRESS_LENGTH);

        ptr = ptr - 32;
        int64 tmpVotingPower = val.votingPower;
        assembly {
            mstore(ptr, tmpVotingPower)
        }

        ptr = ptr + 32 - VALIDATOR_VOTING_POWER_LENGTH - VALIDATOR_PUB_KEY_LENGTH;
        bytes32 tmpPubKey = val.pubKey;
        assembly {
            mstore(ptr, tmpPubKey)
        }
    }

    // input:
    // | chainID   | height   | nextValidatorSetHash | [{validator pubkey, voting power, relayer address, relayer bls pubkey}] |
    // | 32 bytes  | 8 bytes  | 32 bytes             | [{32 bytes, 8 bytes, 20 bytes, 48 bytes}]                               |
    function decodeConsensusState(uint256 ptr, uint256 size, bool validatorSetChanged) internal {
        require(size > CONSENSUS_STATE_BASE_LENGTH, "cs length too short");
        require((size - CONSENSUS_STATE_BASE_LENGTH) % VALIDATOR_BYTES_LENGTH == 0, "invalid cs length");

        ptr = ptr + HEIGHT_LENGTH;
        uint64 tmpHeight;
        assembly {
            tmpHeight := mload(ptr)
        }
        height = tmpHeight;
        console.log("height", height);

        ptr = ptr + VALIDATOR_SET_HASH_LENGTH;
        assembly {
            sstore(nextValidatorSetHash.slot, mload(ptr))
        }

        if (!validatorSetChanged) {
            return;
        }

        ptr = ptr + CHAIN_ID_LENGTH;
        console.log(
            "246 size, CONSENSUS_STATE_BASE_LENGTH, VALIDATOR_BYTES_LENGTH",
            size,
            CONSENSUS_STATE_BASE_LENGTH,
            VALIDATOR_BYTES_LENGTH
        );

        uint256 valNum = (size - CONSENSUS_STATE_BASE_LENGTH) / VALIDATOR_BYTES_LENGTH;
        Validator[] memory newValidatorSet = new Validator[](valNum);
        for (uint256 i = 0; i < valNum; i++) {
            newValidatorSet[i] = decodeValidator(ptr, VALIDATOR_BYTES_LENGTH);
            ptr = ptr + VALIDATOR_BYTES_LENGTH;
        }

        uint256 i = 0;
        uint256 curValidatorSetLen = validatorSet.length;

        console.log("254 valNum, curValidatorSetLen", valNum, curValidatorSetLen);

        for (i = 0; i < valNum && i < curValidatorSetLen; i++) {
            validatorSet[i] = newValidatorSet[i];
        }

        for (; i < curValidatorSetLen; i++) {
            validatorSet.pop();
        }

        for (; i < valNum; i++) {
            validatorSet.push(newValidatorSet[i]);
        }

        console.log("264 validatorSet.length", validatorSet.length);
    }

    function decodeValidator(uint256 ptr, uint256 size) internal returns (Validator memory val) {
        require(size == VALIDATOR_BYTES_LENGTH, "invalid validator bytes length");

        uint256 dst;
        bytes32 tmpPubKey;

        assembly {
            tmpPubKey := mload(ptr)
        }
        val.pubKey = tmpPubKey;

        ptr = ptr + VALIDATOR_VOTING_POWER_LENGTH;
        int64 tmpVotingPower;
        assembly {
            tmpVotingPower := mload(ptr)
        }
        val.votingPower = tmpVotingPower;
        console.log("tmpVotingPower", uint64(tmpVotingPower));

        ptr = ptr + RELAYER_ADDRESS_LENGTH;
        address tmpRelayerAddress;
        assembly {
            tmpRelayerAddress := mload(ptr)
        }
        val.relayerAddress = tmpRelayerAddress;
        console.log("tmpRelayerAddress", tmpRelayerAddress);

        ptr = ptr + VALIDATOR_PUB_KEY_LENGTH;
        val.relayerBlsKey = Memory.toBytes(ptr, RELAYER_BLS_KEY_LENGTH);
        console.log("tmpBlsKey");
        console.logBytes(val.relayerBlsKey);

        return val;
    }
}
