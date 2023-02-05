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
    address public constant PACKAGE_VERIFY_CONTRACT = address(0x0000000000000000000000000000000000000066);
    address public constant HEADER_VALIDATE_CONTRACT = address(0x0000000000000000000000000000000000000067);

    uint256 public constant CHAIN_ID_LENGTH = 32;
    uint256 public constant HEIGHT_LENGTH = 8;
    uint256 public constant VALIDATOR_SET_HASH_LENGTH = 32;
    uint256 public constant CONSENSUS_STATE_BYTES_LENGTH = 32;
    uint256 public constant CONSENSUS_STATE_BASE_LENGTH = CHAIN_ID_LENGTH + HEIGHT_LENGTH + VALIDATOR_SET_HASH_LENGTH;

    uint256 public constant VALIDATOR_PUB_KEY_LENGTH = 32;
    uint256 public constant VALIDATOR_VOTING_POWER_LENGTH = 8;
    uint256 public constant RELAYER_ADDRESS_LENGTH = 20;
    uint256 public constant RELAYER_BLS_KEY_LENGTH = 48;

    uint256 public constant VALIDATOR_BYTES_LENGTH = VALIDATOR_PUB_KEY_LENGTH + VALIDATOR_VOTING_POWER_LENGTH + RELAYER_ADDRESS_LENGTH + RELAYER_BLS_KEY_LENGTH;
    uint256 public constant MESSAGE_HASH_LENGTH = 32;
    uint256 public constant BLS_SIGNATURE_LENGTH = 96;

    /* --------------------- 2. storage --------------------- */
    bytes32 public chainID;
    uint64 public initialHeight;
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

    function syncLightBlock(bytes calldata _lightBlock, uint64 _height) external onlyRelayer returns (bool) {
        require(submitters[_height] == address(0x0), "can't sync duplicated header");
        require(_height > height, "can't sync header before latest height");

        bytes memory input = BytesLib.concat(abi.encode(consensusStateBytes.length), consensusStateBytes);
        bytes memory tmpBlock = _lightBlock;
        input = BytesLib.concat(input, tmpBlock);
        (bool success, bytes memory result) = HEADER_VALIDATE_CONTRACT.staticcall(input);
        require(success && result.length > 0, "header validate failed");

        uint256 ptr = Memory.dataPtr(result);
        uint256 tmp;
        assembly {
            tmp := mload(ptr)
        }

        bool validatorSetChanged = (tmp >> 248) != 0x00;
        uint256 consensusStateLength = tmp & 0xffffffffffffffff;
        ptr = ptr + CONSENSUS_STATE_BYTES_LENGTH;
        decodeConsensusState(ptr, consensusStateLength, validatorSetChanged);
        require(height == _height, "invalid header height");
        submitters[_height] = payable(msg.sender);
        if (validatorSetChanged) {
            consensusStateBytes = Memory.toBytes(ptr, consensusStateLength);
        }

        emit updateConsensusState(_height, validatorSetChanged);

        return true;
    }

    function verifyPackage(bytes calldata _payload, bytes calldata _blsSignature, uint256 _validatorSetBitMap) external view {
        require(_blsSignature.length == BLS_SIGNATURE_LENGTH, "invalid signature length");

        uint256 bitCount;
        bytes32 msgHash = keccak256(_payload);
        bytes memory tmpBlsSig = _blsSignature;
        bytes memory input = BytesLib.concat(abi.encode(msgHash), tmpBlsSig);
        for (uint256 i = 0; i < validatorSet.length; i++) {
            if ((_validatorSetBitMap & (0x1 << i)) != 0) {
                bitCount++;
                input = BytesLib.concat(input, validatorSet[i].relayerBlsKey);
            }
        }
        require(bitCount >= validatorSet.length*2/3, "no majority validators");

        (bool success, bytes memory result) = PACKAGE_VERIFY_CONTRACT.staticcall(input);
        require(success && result.length > 0, "invalid cross-chain package");
    }

    function getRelayers() external view returns (address[] memory) {
        address[] memory relayers = new address[](validatorSet.length);
        for (uint256 i = 0; i < validatorSet.length; i++) {
            relayers[i] = validatorSet[i].relayerAddress;
        }
        return relayers;
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

        ptr = ptr + VALIDATOR_SET_HASH_LENGTH;
        assembly {
            sstore(nextValidatorSetHash.slot, mload(ptr))
        }

        if (!validatorSetChanged) {
            return;
        }

        ptr = ptr + CHAIN_ID_LENGTH;
        uint256 valNum = (size - CONSENSUS_STATE_BASE_LENGTH) / VALIDATOR_BYTES_LENGTH;
        Validator[] memory newValidatorSet = new Validator[](valNum);
        for (uint256 i = 0; i < valNum; i++) {
            newValidatorSet[i] = decodeValidator(ptr, VALIDATOR_BYTES_LENGTH);
            ptr = ptr + VALIDATOR_BYTES_LENGTH;
        }

        uint256 i = 0;
        uint256 curValidatorSetLen = validatorSet.length;
        for (i = 0; i < valNum && i < curValidatorSetLen; i++) {
            validatorSet[i] = newValidatorSet[i];
        }
        for (; i < curValidatorSetLen; i++) {
            validatorSet.pop();
        }
        for (; i < valNum; i++) {
            validatorSet.push(newValidatorSet[i]);
        }
    }

    function decodeValidator(uint256 ptr, uint256 size) internal returns (Validator memory val) {
        require(size == VALIDATOR_BYTES_LENGTH, "invalid validator bytes length");

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

        ptr = ptr + RELAYER_ADDRESS_LENGTH;
        address tmpRelayerAddress;
        assembly {
            tmpRelayerAddress := mload(ptr)
        }
        val.relayerAddress = tmpRelayerAddress;

        ptr = ptr + VALIDATOR_PUB_KEY_LENGTH;
        val.relayerBlsKey = Memory.toBytes(ptr, RELAYER_BLS_KEY_LENGTH);
        return val;
    }
}
