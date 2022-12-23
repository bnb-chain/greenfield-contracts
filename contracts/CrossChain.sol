pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interface/IMiddleLayer.sol";
import "./interface/ITokenHub.sol";
import "./interface/ILightClient.sol";
import "./interface/IRelayerHub.sol";
import "./lib/Memory.sol";
import "./lib/BytesToTypes.sol";
import "./Config.sol";
import "./Governance.sol";


contract CrossChain is Config, Governance, OwnableUpgradeable {

    // constant variables
    string constant public STORE_NAME = "ibc";
    uint256 constant public CROSS_CHAIN_KEY_PREFIX = 0x01006000; // last 6 bytes
    uint8 constant public SYN_PACKAGE = 0x00;
    uint8 constant public ACK_PACKAGE = 0x01;
    uint8 constant public FAIL_ACK_PACKAGE = 0x02;
    uint256 constant public INIT_BATCH_SIZE = 50;

    // governable parameters
    uint256 public batchSizeForOracle;

    uint32 public chainId;

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
    event CrossChainPackage(uint32 chainId, uint64 indexed oracleSequence, uint64 indexed packageSequence, uint8 indexed channelId, bytes payload);
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

    modifier onlyRegisteredContractChannel(uint8 channleId) {
        require(registeredContractChannelMap[msg.sender][channleId], "the contract and channel have not been registered");
        _;
    }

    function initialize() public initializer
    {
        __Ownable_init();

        chainId = uint32(block.chainid);

        // TODO register channels
        batchSizeForOracle = INIT_BATCH_SIZE;

        oracleSequence = -1;
        previousTxHeight = 0;
        txCounter = 0;
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

    function handlePackage(bytes calldata payload, bytes calldata blsSignature, uint256 validatorSet, uint64 packageSequence, uint8 channelId)
    sequenceInOrder(packageSequence, channelId)
    channelSupported(channelId)
    whenNotSuspended
    external {
        bytes memory _payload = payload; // fix error: stack too deep, try removing local variables
        require(ILightClient(LIGHT_CLIENT_ADDR).verifyPackage(_payload, blsSignature, validatorSet, packageSequence, channelId), "invalid signature");

        uint64 _sequence = packageSequence; // fix error: stack too deep, try removing local variables
        uint8 _channelId = channelId; // fix error: stack too deep, try removing local variables
        (bool success, uint8 packageType, uint64 pkgTime, uint256 relayFee, bytes memory msgBytes) = decodePayloadHeader(_payload);
        require(ILightClient(LIGHT_CLIENT_ADDR).verifyPackageRelayer(msg.sender, pkgTime), "invalid relayer");

        if (!success) {
            emit UnsupportedPackage(_sequence, _channelId, _payload);
            return;
        }
        emit ReceivedPackage(packageType, _sequence, _channelId);
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
        emit CrossChainPackage(chainId, uint64(oracleSequence), packageSequence, channelId, payload);
    }

    function sendSynPackage(uint8 channelId, bytes calldata msgBytes, uint256 relayFee)
    onlyRegisteredContractChannel(channelId)
    external {
        uint64 sendSequence = channelSendSequenceMap[channelId];
        _sendPackage(sendSequence, channelId, encodePayload(SYN_PACKAGE, relayFee, msgBytes));
        sendSequence++;
        channelSendSequenceMap[channelId] = sendSequence;
    }

    function updateParam(string calldata key, bytes calldata value)
    onlyGov
    whenNotSuspended
    external {
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
            channelHandlerContractMap[channelId]=handlerContract;
            registeredContractChannelMap[handlerContract][channelId] = true;
            isRelayRewardFromSystemReward[channelId] = isRewardFromSystem;
            emit AddChannel(channelId, handlerContract);
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
            if (handlerContract != address(0x00)) { //channel existing
                registeredContractChannelMap[handlerContract][channelId] = isEnable;
                emit EnableOrDisableChannel(channelId, isEnable);
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
        emit ParamChange(key, value);
    }
}
