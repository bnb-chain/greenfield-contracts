// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interface/IMiddleLayer.sol";
import "./interface/ITokenHub.sol";
import "./interface/ILightClient.sol";
import "./interface/IRelayerHub.sol";
import "./lib/Memory.sol";
import "./lib/BytesToTypes.sol";
import "./Config.sol";

contract CrossChain is Initializable, Config {
    /*----------------- constants -----------------*/
    uint8 public constant SYN_PACKAGE = 0x00;
    uint8 public constant ACK_PACKAGE = 0x01;
    uint8 public constant FAIL_ACK_PACKAGE = 0x02;

    uint256 public constant IN_TURN_RELAYER_VALIDITY_PERIOD = 15 seconds;
    uint256 public constant OUT_TURN_RELAYER_BACKOFF_PERIOD = 3 seconds;

    // 0xebbda044f67428d7e9b472f9124983082bcda4f84f5148ca0a9ccbe06350f196
    bytes32 public constant SUSPEND_PROPOSAL = keccak256("SUSPEND_PROPOSAL");
    // 0xcf82004e82990eca84a75e16ba08aa620238e076e0bc7fc4c641df44bbf5b55a
    bytes32 public constant REOPEN_PROPOSAL = keccak256("REOPEN_PROPOSAL");
    // 0x605b57daa79220f76a5cdc8f5ee40e59093f21a4e1cec30b9b99c555e94c75b9
    bytes32 public constant CANCEL_TRANSFER_PROPOSAL = keccak256("CANCEL_TRANSFER_PROPOSAL");
    // 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
    bytes32 public constant EMPTY_CONTENT_HASH = keccak256("");
    uint256 public constant EMERGENCY_PROPOSAL_EXPIRE_PERIOD = 1 hours;

    /*----------------- storage layer -----------------*/
    bool public isSuspended;
    // proposal type hash => latest emergency proposal
    mapping(bytes32 => EmergencyProposal) public emergencyProposals;
    // proposal type hash => the threshold of proposal approved
    mapping(bytes32 => uint16) public quorumMap;

    // governable parameters
    uint16 public chainId;
    uint16 public gnfdChainId;
    uint256 public batchSizeForOracle;

    //state variables
    uint256 public previousTxHeight;
    uint256 public txCounter;
    int64 public oracleSequence;
    mapping(uint8 => address) public channelHandlerMap;
    mapping(address => mapping(uint8 => bool)) public registeredContractChannelMap;
    mapping(uint8 => uint64) public channelSendSequenceMap;
    mapping(uint8 => uint64) public channelReceiveSequenceMap;

    /*----------------- struct / event / modifier -----------------*/
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
    event CrossChainPackage(
        uint32 srcChainId,
        uint32 dstChainId,
        uint64 indexed oracleSequence,
        uint64 indexed packageSequence,
        uint8 indexed channelId,
        bytes payload
    );
    event ReceivedPackage(uint8 packageType, uint64 indexed packageSequence, uint8 indexed channelId);
    event UnsupportedPackage(uint64 indexed packageSequence, uint8 indexed channelId, bytes payload);
    event UnexpectedRevertInPackageHandler(address indexed contractAddr, string reason);
    event UnexpectedFailureAssertionInPackageHandler(address indexed contractAddr, bytes lowLevelData);
    event ParamChange(string key, bytes value);
    event EnableOrDisableChannel(uint8 indexed channelId, bool isEnable);
    event AddChannel(uint8 indexed channelId, address indexed contractAddr);

    modifier onlyRegisteredContractChannel(uint8 channelId) {
        require(
            registeredContractChannelMap[msg.sender][channelId], "the contract and channel have not been registered"
        );
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

    // TODO we will optimize the gas consumption here.
    modifier onlyRelayer() {
        bool isRelayer;
        address[] memory relayers = ILightClient(LIGHT_CLIENT).getRelayers();
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

    /*----------------- external function -----------------*/
    function initialize(uint16 _gnfdChainId) public initializer {
        require(_gnfdChainId != 0, "zero _gnfdChainId");
        require(PROXY_ADMIN != address(0), "zero PROXY_ADMIN");
        require(GOV_HUB != address(0), "zero GOV_HUB");
        require(CROSS_CHAIN != address(0), "zero CROSS_CHAIN");
        require(TOKEN_HUB != address(0), "zero TOKEN_HUB");
        require(LIGHT_CLIENT != address(0), "zero LIGHT_CLIENT");
        require(RELAYER_HUB != address(0), "zero RELAYER_HUB");

        chainId = uint16(block.chainid);
        gnfdChainId = _gnfdChainId;

        // TODO register other channels
        channelHandlerMap[TRANSFER_IN_CHANNELID] = TOKEN_HUB;
        registeredContractChannelMap[TOKEN_HUB][TRANSFER_IN_CHANNELID] = true;

        channelHandlerMap[TRANSFER_OUT_CHANNELID] = TOKEN_HUB;
        registeredContractChannelMap[TOKEN_HUB][TRANSFER_OUT_CHANNELID] = true;

        channelHandlerMap[GOV_CHANNELID] = GOV_HUB;
        registeredContractChannelMap[TOKEN_HUB][GOV_CHANNELID] = true;

        batchSizeForOracle = 50;

        oracleSequence = -1;
        previousTxHeight = 0;
        txCounter = 0;

        quorumMap[SUSPEND_PROPOSAL] = 1;
        quorumMap[REOPEN_PROPOSAL] = 2;
        quorumMap[CANCEL_TRANSFER_PROPOSAL] = 2;
    }

    function encodePayload(uint8 packageType, uint256 relayFee, uint256 ackRelayFee, bytes memory msgBytes)
        public
        view
        returns (bytes memory)
    {
        return packageType == SYN_PACKAGE
            ? abi.encodePacked(packageType, uint64(block.timestamp), relayFee, ackRelayFee, msgBytes)
            : abi.encodePacked(packageType, uint64(block.timestamp), relayFee, msgBytes);
    }

    function handlePackage(bytes calldata _payload, bytes calldata _blsSignature, uint256 _validatorsBitSet)
        external
        whenNotSuspended
    {
        // 1. decode _payload
        // 1-1 check if the chainId is valid
        (
            bool success,
            uint8 channelId,
            uint64 sequence,
            uint8 packageType,
            uint64 eventTime,
            uint256 relayFee,
            uint256 ackRelayFee,
            bytes memory packageLoad
        ) = _checkPayload(_payload);
        if (!success) {
            emit UnsupportedPackage(sequence, channelId, _payload);
            return;
        }
        emit ReceivedPackage(packageType, sequence, channelId);

        // 1-2 check if the channel is supported
        require(channelHandlerMap[channelId] != address(0), "channel is not supported");
        // 1-3 check if the sequence is in order
        require(sequence == channelReceiveSequenceMap[channelId], "sequence not in order");
        channelReceiveSequenceMap[channelId]++;

        // 2. check valid relayer
        _checkValidRelayer(eventTime);

        // 3. verify bls signature
        require(
            ILightClient(LIGHT_CLIENT).verifyPackage(_payload, _blsSignature, _validatorsBitSet),
            "cross chain package not verified"
        );

        // 4. handle package
        address _handler = channelHandlerMap[channelId];
        if (packageType == SYN_PACKAGE) {
            try IMiddleLayer(_handler).handleSynPackage(channelId, packageLoad) returns (bytes memory responsePayload) {
                if (responsePayload.length != 0) {
                    _sendPackage(
                        channelSendSequenceMap[channelId],
                        channelId,
                        encodePayload(ACK_PACKAGE, ackRelayFee, 0, responsePayload)
                    );
                    channelSendSequenceMap[channelId] = channelSendSequenceMap[channelId] + 1;
                }
            } catch Error(string memory reason) {
                _sendPackage(
                    channelSendSequenceMap[channelId],
                    channelId,
                    encodePayload(FAIL_ACK_PACKAGE, ackRelayFee, 0, packageLoad)
                );
                channelSendSequenceMap[channelId] = channelSendSequenceMap[channelId] + 1;
                emit UnexpectedRevertInPackageHandler(_handler, reason);
            } catch (bytes memory lowLevelData) {
                _sendPackage(
                    channelSendSequenceMap[channelId],
                    channelId,
                    encodePayload(FAIL_ACK_PACKAGE, ackRelayFee, 0, packageLoad)
                );
                channelSendSequenceMap[channelId] = channelSendSequenceMap[channelId] + 1;
                emit UnexpectedFailureAssertionInPackageHandler(_handler, lowLevelData);
            }
        } else if (packageType == ACK_PACKAGE) {
            try IMiddleLayer(_handler).handleAckPackage(channelId, packageLoad) {}
            catch Error(string memory reason) {
                emit UnexpectedRevertInPackageHandler(_handler, reason);
            } catch (bytes memory lowLevelData) {
                emit UnexpectedFailureAssertionInPackageHandler(_handler, lowLevelData);
            }
        } else if (packageType == FAIL_ACK_PACKAGE) {
            try IMiddleLayer(_handler).handleFailAckPackage(channelId, packageLoad) {}
            catch Error(string memory reason) {
                emit UnexpectedRevertInPackageHandler(_handler, reason);
            } catch (bytes memory lowLevelData) {
                emit UnexpectedFailureAssertionInPackageHandler(_handler, lowLevelData);
            }
        }

        IRelayerHub(RELAYER_HUB).addReward(msg.sender, relayFee);
    }

    function sendSynPackage(uint8 channelId, bytes calldata msgBytes, uint256 relayFee, uint256 ackRelayFee)
        external
        onlyRegisteredContractChannel(channelId)
    {
        uint64 sendSequence = channelSendSequenceMap[channelId];
        _sendPackage(sendSequence, channelId, encodePayload(SYN_PACKAGE, relayFee, ackRelayFee, msgBytes));
        sendSequence++;
        channelSendSequenceMap[channelId] = sendSequence;
    }

    function suspend() external onlyRelayer whenNotSuspended {
        bool isExecutable = _approveProposal(SUSPEND_PROPOSAL, EMPTY_CONTENT_HASH);
        if (isExecutable) {
            isSuspended = true;
            emit Suspended(msg.sender);
        }
    }

    function reopen() external onlyRelayer whenSuspended {
        bool isExecutable = _approveProposal(REOPEN_PROPOSAL, EMPTY_CONTENT_HASH);
        if (isExecutable) {
            isSuspended = false;
            emit Reopened(msg.sender);
        }
    }

    function cancelTransfer(address attacker) external onlyRelayer {
        bytes32 _contentHash = keccak256(abi.encode(attacker));
        bool isExecutable = _approveProposal(CANCEL_TRANSFER_PROPOSAL, _contentHash);
        if (isExecutable) {
            ITokenHub(TOKEN_HUB).cancelTransferIn(attacker);
        }
    }

    function updateParam(string calldata key, bytes calldata value) onlyGov external {
        uint256 valueLength = value.length;
        if (Memory.compareStrings(key, "batchSizeForOracle")) {
            require(valueLength == 32, "invalid batchSizeForOracle value length");
            uint256 newBatchSizeForOracle = BytesToTypes.bytesToUint256(valueLength, value);
            require(newBatchSizeForOracle <= 10000 && newBatchSizeForOracle >= 10, "the newBatchSizeForOracle should be in [10, 10000]");
            batchSizeForOracle = newBatchSizeForOracle;
        } else {
            revert("unknown param");
        }
        emit ParamChange(key, value);
    }

    /*----------------- internal function -----------------*/
    /*
    | SrcChainId | DestChainId | ChannelId | Sequence | PackageType | Timestamp | SynRelayerFee | AckRelayerFee(optional) | PackageLoad |
    | 2 bytes    |  2 bytes    |  1 byte   |  8 bytes |  1 byte     |  8 bytes  | 32 bytes      | 32 bytes / 0 bytes      |   len bytes |
    */
    function _checkPayload(bytes calldata payload)
        internal
        view
        returns (
            bool success,
            uint8 channelId,
            uint64 sequence,
            uint8 packageType,
            uint64 time,
            uint256 relayFee,
            uint256 ackRelayFee, // optional
            bytes memory packageLoad
        )
    {
        if (payload.length < 54) {
            return (false, 0, 0, 0, 0, 0, 0, "");
        }

        bytes memory _payload = payload;
        uint256 ptr;
        {
            uint16 srcChainId;
            uint16 dstChainId;
            assembly {
                ptr := _payload

                srcChainId := mload(add(ptr, 2))
                dstChainId := mload(add(ptr, 4))
            }
            require(srcChainId == gnfdChainId, "invalid source chainId");
            require(dstChainId == chainId, "invalid destination chainId");
        }

        assembly {
            channelId := mload(add(ptr, 5))
            sequence := mload(add(ptr, 13))
            packageType := mload(add(ptr, 14))
            time := mload(add(ptr, 22))
            relayFee := mload(add(ptr, 54))
        }

        if (packageType == SYN_PACKAGE) {
            if (payload.length < 86) {
                return (false, 0, 0, 0, 0, 0, 0, "");
            }

            assembly {
                ackRelayFee := mload(add(ptr, 86))
            }
            packageLoad = payload[86:];
        } else {
            ackRelayFee = 0;
            packageLoad = payload[54:];
        }

        success = true;
    }

    function _checkValidRelayer(uint64 eventTime) internal view {
        address[] memory relayers = ILightClient(LIGHT_CLIENT).getRelayers();

        // TODO we will optimize the check in the future.
        // check if it is the valid relayer
        uint256 _totalRelayers = relayers.length;
        uint256 _currentIndex = uint256(eventTime) % _totalRelayers;
        if (msg.sender != relayers[_currentIndex]) {
            uint256 diffSeconds = block.timestamp - uint256(eventTime);
            require(diffSeconds >= IN_TURN_RELAYER_VALIDITY_PERIOD, "not in turn relayer");
            diffSeconds -= IN_TURN_RELAYER_VALIDITY_PERIOD;

            bool isValidRelayer;
            for (uint256 i; i < _totalRelayers; ++i) {
                _currentIndex = (_currentIndex + 1) % _totalRelayers;
                if (msg.sender == relayers[_currentIndex]) {
                    isValidRelayer = true;
                    break;
                }

                if (diffSeconds < OUT_TURN_RELAYER_BACKOFF_PERIOD) {
                    break;
                }
                diffSeconds -= OUT_TURN_RELAYER_BACKOFF_PERIOD;
            }

            require(isValidRelayer, "invalid candidate relayer");
        }
    }

    function _sendPackage(uint64 packageSequence, uint8 channelId, bytes memory payload) internal whenNotSuspended {
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
        emit CrossChainPackage(chainId, gnfdChainId, uint64(oracleSequence), packageSequence, channelId, payload);
    }

    function _approveProposal(bytes32 proposalTypeHash, bytes32 _contentHash) internal returns (bool isExecutable) {
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
}
