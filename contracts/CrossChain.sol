pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./middle-layer/BFSValidatorSet.sol";
import "./middle-layer/EndPoint.sol";

contract CrossChain is OwnableUpgradeable {
    // constant variables
    uint256 constant public CROSS_CHAIN_KEY_PREFIX = 0x01006000; // last 6 bytes
    uint8 constant public SYN_PACKAGE = 0x00;
    uint8 constant public ACK_PACKAGE = 0x01;
    uint8 constant public FAIL_ACK_PACKAGE = 0x02;
    uint256 constant public INIT_BATCH_SIZE = 50;

    // SUSPEND_PROPOSAL = 0xebbda044f67428d7e9b472f9124983082bcda4f84f5148ca0a9ccbe06350f196
    bytes32 public constant SUSPEND_PROPOSAL = keccak256("SUSPEND_PROPOSAL");
    // REOPEN_PROPOSAL = 0xcf82004e82990eca84a75e16ba08aa620238e076e0bc7fc4c641df44bbf5b55a
    bytes32 public constant REOPEN_PROPOSAL = keccak256("REOPEN_PROPOSAL");
    // CANCEL_TRANSFER_PROPOSAL = 0x605b57daa79220f76a5cdc8f5ee40e59093f21a4e1cec30b9b99c555e94c75b9
    bytes32 public constant CANCEL_TRANSFER_PROPOSAL = keccak256("CANCEL_TRANSFER_PROPOSAL");
    // EMPTY_CONTENT_HASH = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
    bytes32 public constant EMPTY_CONTENT_HASH = keccak256("");
    uint16 public constant INIT_SUSPEND_QUORUM = 1;
    uint16 public constant INIT_REOPEN_QUORUM = 2;
    uint16 public constant INIT_CANCEL_TRANSFER_QUORUM = 2;
    uint256 public constant EMERGENCY_PROPOSAL_EXPIRE_PERIOD = 1 hours;

    // governable parameters
    uint256 public batchSizeForOracle;

    //state variables
    uint256 public previousTxHeight;
    uint256 public txCounter;
    int64 public oracleSequence;
    mapping(uint8 => address) public channelHandlerContractMap;
    mapping(address => mapping(uint8 => bool))public registeredContractChannelMap;
    mapping(uint8 => uint64) public channelSendSequenceMap;
    mapping(uint8 => uint64) public channelReceiveSequenceMap;
    mapping(uint8 => bool) public isRelayRewardFromSystemReward;

    // to prevent the utilization of ancient block header
    mapping(uint8 => uint64) public channelSyncedHeaderMap;

    bool public isSuspended;
    // proposal type hash => latest emergency proposal
    mapping(bytes32 => EmergencyProposal) public emergencyProposals;
    // proposal type hash => the threshold of proposal approved
    mapping(bytes32 => uint16) public quorumMap;
    // IAVL key hash => is challenged
    mapping(bytes32 => bool) public challenged;

    // struct
    struct EmergencyProposal {
        uint16 quorum;
        uint128 expiredAt;
        bytes32 contentHash;

        address[] approvers;
    }

    // event
    event crossChainPackage(uint16 chainId, uint64 indexed oracleSequence, uint64 indexed packageSequence, uint8 indexed channelId, bytes payload);
    event receivedPackage(uint8 packageType, uint64 indexed packageSequence, uint8 indexed channelId);
    event unsupportedPackage(uint64 indexed packageSequence, uint8 indexed channelId, bytes payload);
    event unexpectedRevertInPackageHandler(address indexed contractAddr, string reason);
    event unexpectedFailureAssertionInPackageHandler(address indexed contractAddr, bytes lowLevelData);
    event paramChange(string key, bytes value);
    event enableOrDisableChannel(uint8 indexed channelId, bool isEnable);
    event addChannel(uint8 indexed channelId, address indexed contractAddr);

    event ProposalSubmitted(
        bytes32 indexed proposalTypeHash,
        address indexed proposer,
        uint128 quorum,
        uint128 expiredAt,
        bytes32 contentHash
    );
    event Suspended(address indexed executor);
    event Reopened(address indexed executor);
    event SuccessChallenge(
        address indexed challenger,
        uint64 packageSequence,
        uint8 channelId
    );

    modifier sequenceInOrder(uint64 _sequence, uint8 _channelID) {
        uint64 expectedSequence = channelReceiveSequenceMap[_channelID];
        require(_sequence == expectedSequence, "sequence not in order");

        channelReceiveSequenceMap[_channelID] = expectedSequence + 1;
        _;
    }

    modifier channelSupported(uint8 _channelID) {
        require(channelHandlerContractMap[_channelID] != address(0x0), "channel is not supported");
        _;
    }

    modifier onlyRegisteredContractChannel(uint8 channelId) {
        require(registeredContractChannelMap[msg.sender][channelId], "the contract and channel have not been registered");
        _;
    }

    modifier whenNotSuspended() {
        require(!isSuspended, "suspended");
        _;
    }

    modifier whenSuspended() {
        require(isSuspended, "not suspended");
        _;
    }

    function initialize()
    public
    initializer
    {
        __Ownable_init();
    }

    function _RLPEncode(uint8 eventType, bytes memory msgBytes) internal pure returns(bytes memory output) {
        bytes[] memory elements = new bytes[](2);
        elements[0] = eventType.encodeUint();
        elements[1] = msgBytes.encodeBytes();
        output = elements.encodeList();
    }

    // SYN message is RLP encoded.
    // The failureHandling is to indicate how the application would like to process the failure.
    // The eventType here is used to support different operations in one channel.
    // The appBytes must allow the application layer to add custom fields
    function encodeSynMessage(uint8 eventType, uint8 failureHandling, address receiver, uint256 gasLimit, address refundAddress, bytes memory appMsg) public returns (bytes memory synMessage){
        // TODO
    }

    // ACK message is RLP encoded
    function encodeAckMessage(uint8 eventType, bytes memory appBytes) {
        // TODO
    }

    function encodeAppMessage(bytes middleLayerMsg, bytes memory appLayerMsg) returns (bytes memory) {
        // TODO
    }

    function encodePayload(uint8 packageType, uint64 timestamp, uint256 relayFee, bytes memory msgBytes) public pure returns (bytes memory) {
        uint256 payloadLength = msgBytes.length + 33;
        bytes memory payload = new bytes(payloadLength);
        // TODO
        return payload;
    }

    // | type   | timestamp | relayFee   | package  |
    // | 1 byte | 8 bytes   | 32 bytes   | bytes    |
    function decodePayloadHeader(bytes memory payload)
    internal
    pure
    returns (
        bool success,
        uint8 packageType,
        uint64 timestamp,
        uint256 relayFee,
        bytes memory msgBytes
    ) {
        // TODO
    }

    function handlePackage(bytes calldata payload, bytes calldata signature, uint256 validatorSetVersion, uint64 packageSequence, uint8 channelId)
    onlyInit
    onlyRelayer
    sequenceInOrder(packageSequence, channelId)
    channelSupported(channelId)
    whenNotSuspended
    external {
        // TODO
        // MiddleWare:
        // 1. BFSValidatorSet
        // 2. TokenHub
        // 3. EndPoint
    }

    function sendPackage(uint64 packageSequence, uint8 channelId, bytes memory payload) internal whenNotSuspended {
        if (block.number > previousTxHeight) {
            oracleSequence++;
            txCounter = 1;
            previousTxHeight = block.number;
        } else {
            txCounter++;
            if (txCounter > batchSizeForOracle) {
                oracleSequence++;
                txCounter = 1;
            }
        }
        emit crossChainPackage(bscChainID, uint64(oracleSequence), packageSequence, channelId, payload);
    }

    function sendSynPackage(uint8 channelId, bytes calldata msgBytes, uint256 relayFee)
    onlyInit
    onlyRegisteredContractChannel(channelId)
    external override {
        uint64 sendSequence = channelSendSequenceMap[channelId];
        sendPackage(sendSequence, channelId, encodePayload(SYN_PACKAGE, relayFee, msgBytes));
        sendSequence++;
        channelSendSequenceMap[channelId] = sendSequence;
    }

    function cachePackage(address dstAddress, uint256 sequence, byte32 msgHash) external onlyEndpoint {

    }

    function retryPackage(address dstAddress, bytes memory msg) external onlyEndpoint {

    }

    function skipPackage(address dstAddress, uint256 sequence) external onlyEndpoint {

    }

    function suspend() onlyRelayer whenNotSuspended external {
        bool isExecutable = _approveProposal(SUSPEND_PROPOSAL, EMPTY_CONTENT_HASH);
        if (isExecutable) {
            _suspend();
        }
    }

    function reopen() onlyRelayer whenSuspended external {
        bool isExecutable = _approveProposal(REOPEN_PROPOSAL, EMPTY_CONTENT_HASH);
        if (isExecutable) {
            isSuspended = false;
            emit Reopened(msg.sender);
        }
    }

    function cancelTransfer(address tokenAddr, address attacker) onlyRelayer external {
        bytes32 _contentHash = keccak256(abi.encode(tokenAddr, attacker));
        bool isExecutable = _approveProposal(CANCEL_TRANSFER_PROPOSAL, _contentHash);
        if (isExecutable) {
            ITokenHub(TOKEN_HUB_ADDR).cancelTransferIn(tokenAddr, attacker);
        }
    }

    function _approveProposal(bytes32 proposalTypeHash, bytes32 _contentHash) internal returns (bool isExecutable) {
        if (quorumMap[proposalTypeHash] == 0) {
            quorumMap[SUSPEND_PROPOSAL] = INIT_SUSPEND_QUORUM;
            quorumMap[REOPEN_PROPOSAL] = INIT_REOPEN_QUORUM;
            quorumMap[CANCEL_TRANSFER_PROPOSAL] = INIT_CANCEL_TRANSFER_QUORUM;
        }

        EmergencyProposal storage p = emergencyProposals[proposalTypeHash];

        // It is ok if there is an evil validator always cancel the previous vote,
        // the credible validator could use private transaction service to send a batch tx including 2 approve transactions
        if (block.timestamp >= p.expiredAt || p.contentHash != _contentHash) {
            // current proposal expired / not exist or not same with the new, create a new EmergencyProposal
            p.quorum = quorumMap[proposalTypeHash];
            p.expiredAt = uint128(block.timestamp + EMERGENCY_PROPOSAL_EXPIRE_PERIOD);
            p.contentHash = _contentHash;
            p.approvers.push(msg.sender);

            emit ProposalSubmitted(proposalTypeHash, msg.sender, p.quorum, p.expiredAt, _contentHash);
        } else {
            // current proposal exists
            for (uint256 i = 0; i < p.approvers.length; ++i) {
                require(p.approvers[i] != msg.sender, "already approved");
            }
            p.approvers.push(msg.sender);
        }

        if (p.approvers.length >= p.quorum) {
            // 1. remove current proposal
            delete emergencyProposals[proposalTypeHash];

            // 2. exec this proposal
            return true;
        }

        return false;
    }

    function _suspend() whenNotSuspended internal {
        isSuspended = true;
        emit Suspended(msg.sender);
    }

    function updateParam(string calldata key, bytes calldata value)
    onlyGov
    whenNotSuspended
    external override {
        if (Memory.compareStrings(key, "batchSizeForOracle")) {
            uint256 newBatchSizeForOracle = BytesToTypes.bytesToUint256(32, value);
            require(newBatchSizeForOracle <= 10000 && newBatchSizeForOracle >= 10, "the newBatchSizeForOracle should be in [10, 10000]");
            batchSizeForOracle = newBatchSizeForOracle;
        } else if (Memory.compareStrings(key, "addOrUpdateChannel")) {
            bytes memory valueLocal = value;
            require(valueLocal.length == 22, "length of value for addOrUpdateChannel should be 22, channelId:isFromSystem:handlerAddress");
            uint8 channelId;
            assembly {
                channelId := mload(add(valueLocal, 1))
            }

            uint8 rewardConfig;
            assembly {
                rewardConfig := mload(add(valueLocal, 2))
            }
            bool isRewardFromSystem = (rewardConfig == 0x0);

            address handlerContract;
            assembly {
                handlerContract := mload(add(valueLocal, 22))
            }

            require(isContract(handlerContract), "address is not a contract");
            channelHandlerContractMap[channelId] = handlerContract;
            registeredContractChannelMap[handlerContract][channelId] = true;
            isRelayRewardFromSystemReward[channelId] = isRewardFromSystem;
            emit addChannel(channelId, handlerContract);
        } else if (Memory.compareStrings(key, "enableOrDisableChannel")) {
            bytes memory valueLocal = value;
            require(valueLocal.length == 2, "length of value for enableOrDisableChannel should be 2, channelId:isEnable");

            uint8 channelId;
            assembly {
                channelId := mload(add(valueLocal, 1))
            }
            uint8 status;
            assembly {
                status := mload(add(valueLocal, 2))
            }
            bool isEnable = (status == 1);

            address handlerContract = channelHandlerContractMap[channelId];
            if (handlerContract != address(0x00)) {//channel existing
                registeredContractChannelMap[handlerContract][channelId] = isEnable;
                emit enableOrDisableChannel(channelId, isEnable);
            }
        } else if (Memory.compareStrings(key, "suspendQuorum")) {
            require(value.length == 2, "length of value for suspendQuorum should be 2");
            uint16 suspendQuorum = BytesToTypes.bytesToUint16(32, value);
            require(suspendQuorum > 0 && suspendQuorum < 100, "invalid suspend quorum");
            quorumMap[SUSPEND_PROPOSAL] = suspendQuorum;
        } else if (Memory.compareStrings(key, "reopenQuorum")) {
            require(value.length == 2, "length of value for reopenQuorum should be 2");
            uint16 reopenQuorum = BytesToTypes.bytesToUint16(32, value);
            require(reopenQuorum > 0 && reopenQuorum < 100, "invalid reopen quorum");
            quorumMap[REOPEN_PROPOSAL] = reopenQuorum;
        } else if (Memory.compareStrings(key, "cancelTransferQuorum")) {
            require(value.length == 2, "length of value for cancelTransferQuorum should be 2");
            uint16 cancelTransferQuorum = BytesToTypes.bytesToUint16(32, value);
            require(cancelTransferQuorum > 0 && cancelTransferQuorum < 100, "invalid cancel transfer quorum");
            quorumMap[CANCEL_TRANSFER_PROPOSAL] = cancelTransferQuorum;
        } else {
            require(false, "unknown param");
        }
        emit paramChange(key, value);
    }
}
