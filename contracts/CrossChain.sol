pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interface/IMiddleLayer.sol";
import "./interface/IGovHub.sol";
import "./interface/ITokenHub.sol";
import "./interface/ILightClient.sol";
import "./interface/IRelayerHub.sol";
import "./lib/Memory.sol";
import "./lib/BytesToTypes.sol";
import "./Config.sol";
import "./Governance.sol";


contract CrossChain is Config, Governance, OwnableUpgradeable {

    // constant variables
    uint8 constant public SYN_PACKAGE = 0x00;
    uint8 constant public ACK_PACKAGE = 0x01;
    uint8 constant public FAIL_ACK_PACKAGE = 0x02;

    uint256 constant public IN_TURN_RELAYER_VALIDITY_PERIOD = 15 seconds;
    uint256 constant public OUT_TURN_RELAYER_BACKOFF_PERIOD = 3 seconds;

    // governable parameters
    uint32 public chainId;
    uint32 public insChainId;
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
    
    // event
    event CrossChainPackage(uint32 srcChainId, uint32 dstChainId, uint64 indexed oracleSequence, uint64 indexed packageSequence, uint8 indexed channelId, bytes payload);
    event ReceivedPackage(uint8 packageType, uint64 indexed packageSequence, uint8 indexed channelId);
    event UnsupportedPackage(uint64 indexed packageSequence, uint8 indexed channelId, bytes payload);
    event UnexpectedRevertInPackageHandler(address indexed contractAddr, string reason);
    event UnexpectedFailureAssertionInPackageHandler(address indexed contractAddr, bytes lowLevelData);
    event ParamChange(string key, bytes value);
    event EnableOrDisableChannel(uint8 indexed channelId, bool isEnable);
    event AddChannel(uint8 indexed channelId, address indexed contractAddr);

    modifier sequenceInOrder(uint64 _sequence, uint8 _channelID) {
        uint64 expectedSequence = channelReceiveSequenceMap[_channelID];
        require(_sequence == expectedSequence, "sequence not in order");

        channelReceiveSequenceMap[_channelID]=expectedSequence+1;
        _;
    }

    modifier channelSupported(uint8 _channelID) {
        require(channelHandlerContractMap[_channelID]!=address(0x0), "channel is not supported");
        _;
    }

    modifier onlyRegisteredContractChannel(uint8 channelId) {
        require(registeredContractChannelMap[msg.sender][channelId], "the contract and channel have not been registered");
        _;
    }

    function initialize(uint32 _insChainId, address _govHub) public initializer {
        require(_insChainId != 0, "zero _insChainId");
        require(_govHub != address (0), "zero govHub");

        __Ownable_init();

        chainId = uint32(block.chainid);
        insChainId = _insChainId;
        govHub = _govHub;

        // TODO register channels
        address _tokenHub = IGovHub(_govHub).tokenHub();
        channelHandlerContractMap[TRANSFER_IN_CHANNELID] = _tokenHub;
        channelHandlerContractMap[TRANSFER_OUT_CHANNELID] = _tokenHub;
        channelHandlerContractMap[GOV_CHANNELID] = _govHub;

        batchSizeForOracle = 50;

        oracleSequence = -1;
        previousTxHeight = 0;
        txCounter = 0;

        quorumMap[SUSPEND_PROPOSAL] = 1;
        quorumMap[REOPEN_PROPOSAL] = 2;
        quorumMap[CANCEL_TRANSFER_PROPOSAL] = 2;
    }

    function encodePayload(uint8 packageType, uint256 relayFee, bytes memory msgBytes) public view returns(bytes memory) {
        return abi.encodePacked(packageType, uint64(block.timestamp), relayFee, msgBytes);
    }

    // | packageType |  timestamp  |  relayFee  |  package  |
    // | 1 byte      |  8 bytes    |  32 bytes  |  bytes    |
    function decodePayloadHeader(bytes memory payload) internal pure returns(bool, uint8 packageType, uint64 time, uint256 relayFee, bytes memory msgBytes) {
        if (payload.length < 41) {
            return (false, 0, 0, 0, new bytes(0));
        }

        uint256 ptr;
        assembly {
            ptr := payload
        }

        ptr += 1;
        assembly {
            packageType := mload(ptr)
        }

        ptr += 8;
        assembly {
            time := mload(ptr)
        }

        ptr += 32;
        assembly {
            relayFee := mload(ptr)
        }

        ptr += 32;
        msgBytes = new bytes(payload.length - 41);
        (uint256 dst, ) = Memory.fromBytes(msgBytes);
        Memory.copy(ptr, dst, payload.length - 41);

        return (true, packageType, time, relayFee, msgBytes);
    }

    function handlePackage(
        bytes calldata payload,
        bytes calldata blsSignature,
        uint256 validatorsBitSet,
        uint64 packageSequence,
        uint8 channelId
    ) external
    sequenceInOrder(packageSequence, channelId)
    channelSupported(channelId)
    whenNotSuspended {
        uint64 _sequence = packageSequence; // fix error: stack too deep, try removing local variables
        uint8 _channelId = channelId; // fix error: stack too deep, try removing local variables
        bytes memory _payload = payload; // fix error: stack too deep, try removing local variables
        bytes memory _blsSignature = blsSignature; // fix error: stack too deep, try removing local variables
        uint256 _validatorsBitSet = validatorsBitSet; // fix error: stack too deep, try removing local variables

        bytes memory _pkgKey = abi.encodePacked(insChainId, chainId, channelId, packageSequence);

        address _lightClient = IGovHub(govHub).lightClient();
        ILightClient(_lightClient).verifyPackage(_pkgKey, _payload, _blsSignature, _validatorsBitSet);

        (bool success, uint8 packageType, uint64 eventTime, uint256 relayFee, bytes memory msgBytes) = decodePayloadHeader(_payload);
        if (!success) {
            emit UnsupportedPackage(_sequence, _channelId, _payload);
            return;
        }
        emit ReceivedPackage(packageType, _sequence, _channelId);

        _checkValidRelayer(eventTime, _lightClient);

        if (packageType == SYN_PACKAGE) {
            address handlerContract = channelHandlerContractMap[_channelId];
            try IMiddleLayer(handlerContract).handleSynPackage(_channelId, msgBytes) returns (bytes memory responsePayload) {
                if (responsePayload.length!=0) {
                    _sendPackage(channelSendSequenceMap[_channelId], _channelId, encodePayload(ACK_PACKAGE, 0, responsePayload));
                    channelSendSequenceMap[_channelId] = channelSendSequenceMap[_channelId] + 1;
                }
            } catch Error(string memory reason) {
                _sendPackage(channelSendSequenceMap[_channelId], _channelId, encodePayload(FAIL_ACK_PACKAGE, 0, msgBytes));
                channelSendSequenceMap[_channelId] = channelSendSequenceMap[_channelId] + 1;
                emit UnexpectedRevertInPackageHandler(handlerContract, reason);
            } catch (bytes memory lowLevelData) {
                _sendPackage(channelSendSequenceMap[_channelId], _channelId, encodePayload(FAIL_ACK_PACKAGE, 0, msgBytes));
                channelSendSequenceMap[_channelId] = channelSendSequenceMap[_channelId] + 1;
                emit UnexpectedFailureAssertionInPackageHandler(handlerContract, lowLevelData);
            }
        } else if (packageType == ACK_PACKAGE) {
            address handlerContract = channelHandlerContractMap[_channelId];
            try IMiddleLayer(handlerContract).handleAckPackage(_channelId, msgBytes) {
            } catch Error(string memory reason) {
                emit UnexpectedRevertInPackageHandler(handlerContract, reason);
            } catch (bytes memory lowLevelData) {
                emit UnexpectedFailureAssertionInPackageHandler(handlerContract, lowLevelData);
            }
        } else if (packageType == FAIL_ACK_PACKAGE) {
            address handlerContract = channelHandlerContractMap[_channelId];
            try IMiddleLayer(handlerContract).handleFailAckPackage(_channelId, msgBytes) {
            } catch Error(string memory reason) {
                emit UnexpectedRevertInPackageHandler(handlerContract, reason);
            } catch (bytes memory lowLevelData) {
                emit UnexpectedFailureAssertionInPackageHandler(handlerContract, lowLevelData);
            }
        }
    }

    function _checkValidRelayer(uint64 eventTime, address _lightClient) internal view {
        address[] memory relayers = ILightClient(_lightClient).getRelayers();

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
        emit CrossChainPackage(chainId, insChainId, uint64(oracleSequence), packageSequence, channelId, payload);
    }

    function sendSynPackage(uint8 channelId, bytes calldata msgBytes, uint256 relayFee)
    onlyRegisteredContractChannel(channelId)
    external {
        uint64 sendSequence = channelSendSequenceMap[channelId];
        _sendPackage(sendSequence, channelId, encodePayload(SYN_PACKAGE, relayFee, msgBytes));
        sendSequence++;
        channelSendSequenceMap[channelId] = sendSequence;
    }
}
