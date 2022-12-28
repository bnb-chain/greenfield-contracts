pragma solidity ^0.8.0;

import "./interface/ITokenHub.sol";
import "./Config.sol";

abstract contract Governance is Config {
    // 0xebbda044f67428d7e9b472f9124983082bcda4f84f5148ca0a9ccbe06350f196
    bytes32 public constant SUSPEND_PROPOSAL = keccak256("SUSPEND_PROPOSAL");
    // 0xcf82004e82990eca84a75e16ba08aa620238e076e0bc7fc4c641df44bbf5b55a
    bytes32 public constant REOPEN_PROPOSAL = keccak256("REOPEN_PROPOSAL");
    // 0x605b57daa79220f76a5cdc8f5ee40e59093f21a4e1cec30b9b99c555e94c75b9
    bytes32 public constant CANCEL_TRANSFER_PROPOSAL = keccak256("CANCEL_TRANSFER_PROPOSAL");
    // 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
    bytes32 public constant EMPTY_CONTENT_HASH = keccak256("");
    uint16 public constant INIT_SUSPEND_QUORUM = 1;
    uint16 public constant INIT_REOPEN_QUORUM = 2;
    uint16 public constant INIT_CANCEL_TRANSFER_QUORUM = 2;
    uint256 public constant EMERGENCY_PROPOSAL_EXPIRE_PERIOD = 1 hours;

    bool public isSuspended;
    // proposal type hash => latest emergency proposal
    mapping(bytes32 => EmergencyProposal) public emergencyProposals;
    // proposal type hash => the threshold of proposal approved
    mapping(bytes32 => uint16) public quorumMap;
    // IAVL key hash => is challenged
    mapping(bytes32 => bool) public challenged;

    struct EmergencyProposal {
        uint16 quorum;
        uint128 expiredAt;
        bytes32 contentHash;

        address[] approvers;
    }

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

    modifier whenNotSuspended() {
        require(!isSuspended, "suspended");
        _;
    }

    modifier whenSuspended() {
        require(isSuspended, "not suspended");
        _;
    }

    // Not reliable, do not use when need strong verify
    function isContract(address addr) internal view returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

    function suspend() onlyRelayers whenNotSuspended external {
        bool isExecutable = _approveProposal(SUSPEND_PROPOSAL, EMPTY_CONTENT_HASH);
        if (isExecutable) {
            _suspend();
        }
    }

    function reopen() onlyRelayers whenSuspended external {
        bool isExecutable = _approveProposal(REOPEN_PROPOSAL, EMPTY_CONTENT_HASH);
        if (isExecutable) {
            isSuspended = false;
            emit Reopened(msg.sender);
        }
    }

    function cancelTransfer(address tokenAddr, address attacker) onlyRelayers external {
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
            p.approvers = [msg.sender];

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
}
