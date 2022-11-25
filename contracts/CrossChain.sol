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
    event CrossChainPackage(uint16 chainId, uint64 indexed oracleSequence, uint64 indexed packageSequence, uint8 indexed channelId, bytes payload);
    event receivedPackage(uint8 packageType, uint64 indexed packageSequence, uint8 indexed channelId);
    event unsupportedPackage(uint64 indexed packageSequence, uint8 indexed channelId, bytes payload);
    event unexpectedRevertInPackageHandler(address indexed contractAddr, string reason);
    event unexpectedFailureAssertionInPackageHandler(address indexed contractAddr, bytes lowLevelData);
    event paramChange(string key, bytes value);
    event enableOrDisableChannel(uint8 indexed channelId, bool isEnable);
    event addChannel(uint8 indexed channelId, address indexed contractAddr);


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

    modifier headerInOrder(uint64 height, uint8 channelId) {
        require(height >= channelSyncedHeaderMap[channelId], "too old header");
        if (height != channelSyncedHeaderMap[channelId]) {
            channelSyncedHeaderMap[channelId] = height;
        }
        _;
    }


    // | length   | prefix | sourceChainID| destinationChainID | channelID | sequence |
    // | 32 bytes | 1 byte | 2 bytes      | 2 bytes            |  1 bytes  | 8 bytes  |
    function generateKey(uint64 _sequence, uint8 _channelID) internal pure returns(bytes memory) {
        uint256 fullCROSS_CHAIN_KEY_PREFIX = CROSS_CHAIN_KEY_PREFIX | _channelID;
        bytes memory key = new bytes(14);

        uint256 ptr;
        assembly {
            ptr := add(key, 14)
        }
        assembly {
            mstore(ptr, _sequence)
        }
        ptr -= 8;
        assembly {
            mstore(ptr, fullCROSS_CHAIN_KEY_PREFIX)
        }
        ptr -= 6;
        assembly {
            mstore(ptr, 14)
        }
        return key;
    }

    function initialize() public initializer
    {
        __Ownable_init();

        // TODO register channels
        batchSizeForOracle = INIT_BATCH_SIZE;

        oracleSequence = -1;
        previousTxHeight = 0;
        txCounter = 0;
    }

    function encodePayload(uint8 packageType, uint256 relayFee, bytes memory msgBytes) public pure returns(bytes memory) {
        uint64 timestamp = uint64(block.timestamp);
        uint256 payloadLength = msgBytes.length + 1 + 8 + 32; // packageType, timestamp, relayFee, msgBytes
        bytes memory payload = new bytes(payloadLength);
        uint256 ptr;
        assembly {
            ptr := payload
        }
        ptr += 1 + 8 + 32;

        assembly {
            mstore(ptr, relayFee)
        }

        ptr-=32;
        assembly {
            mstore(ptr, packageType)
        }

        ptr-=8;
        assembly {
            mstore(ptr, timestamp)
        }

        ptr-=1;
        assembly {
            mstore(ptr, payloadLength)
        }

        ptr+=65;
        (uint256 src,) = Memory.fromBytes(msgBytes);
        Memory.copy(src, ptr, msgBytes.length);

        return payload;
    }

    // | type   | relayFee   |package  |
    // | 1 byte | 32 bytes   | bytes    |
    function decodePayloadHeader(bytes memory payload) internal pure returns(bool, uint8, uint256, bytes memory) {
        if (payload.length < 33) {
            return (false, 0, 0, new bytes(0));
        }

        uint256 ptr;
        assembly {
            ptr := payload
        }

        uint8 packageType;
        ptr+=1;
        assembly {
            packageType := mload(ptr)
        }

        uint256 relayFee;
        ptr+=32;
        assembly {
            relayFee := mload(ptr)
        }

        ptr+=32;
        bytes memory msgBytes = new bytes(payload.length-33);
        (uint256 dst, ) = Memory.fromBytes(msgBytes);
        Memory.copy(ptr, dst, payload.length-33);

        return (true, packageType, relayFee, msgBytes);
    }

    function handlePackage(bytes calldata payload, bytes calldata proof, uint64 height, uint64 packageSequence, uint8 channelId)
    onlyRelayer
    sequenceInOrder(packageSequence, channelId)
    channelSupported(channelId)
    whenNotSuspended
    external {
        bytes memory payloadLocal = payload; // fix error: stack too deep, try removing local variables
        bytes memory proofLocal = proof; // fix error: stack too deep, try removing local variables
//        require(MerkleProof.validateMerkleProof(ILightClient(LIGHT_CLIENT_ADDR).getAppHash(height), STORE_NAME, generateKey(packageSequence, channelId), payloadLocal, proofLocal), "invalid merkle proof");

        address payable headerRelayer = ILightClient(LIGHT_CLIENT_ADDR).getSubmitter(height);

        uint64 sequenceLocal = packageSequence; // fix error: stack too deep, try removing local variables
        uint8 channelIdLocal = channelId; // fix error: stack too deep, try removing local variables
        (bool success, uint8 packageType, uint256 relayFee, bytes memory msgBytes) = decodePayloadHeader(payloadLocal);
        if (!success) {
            emit unsupportedPackage(sequenceLocal, channelIdLocal, payloadLocal);
            return;
        }
        emit receivedPackage(packageType, sequenceLocal, channelIdLocal);
        if (packageType == SYN_PACKAGE) {
            address handlerContract = channelHandlerContractMap[channelIdLocal];
            try IMiddleLayer(handlerContract).handleSynPackage(channelIdLocal, msgBytes) returns (bytes memory responsePayload) {
                if (responsePayload.length!=0) {
                    sendPackage(channelSendSequenceMap[channelIdLocal], channelIdLocal, encodePayload(ACK_PACKAGE, 0, responsePayload));
                    channelSendSequenceMap[channelIdLocal] = channelSendSequenceMap[channelIdLocal] + 1;
                }
            } catch Error(string memory reason) {
                sendPackage(channelSendSequenceMap[channelIdLocal], channelIdLocal, encodePayload(FAIL_ACK_PACKAGE, 0, msgBytes));
                channelSendSequenceMap[channelIdLocal] = channelSendSequenceMap[channelIdLocal] + 1;
                emit unexpectedRevertInPackageHandler(handlerContract, reason);
            } catch (bytes memory lowLevelData) {
                sendPackage(channelSendSequenceMap[channelIdLocal], channelIdLocal, encodePayload(FAIL_ACK_PACKAGE, 0, msgBytes));
                channelSendSequenceMap[channelIdLocal] = channelSendSequenceMap[channelIdLocal] + 1;
                emit unexpectedFailureAssertionInPackageHandler(handlerContract, lowLevelData);
            }
        } else if (packageType == ACK_PACKAGE) {
            address handlerContract = channelHandlerContractMap[channelIdLocal];
            try IMiddleLayer(handlerContract).handleAckPackage(channelIdLocal, msgBytes) {
            } catch Error(string memory reason) {
                emit unexpectedRevertInPackageHandler(handlerContract, reason);
            } catch (bytes memory lowLevelData) {
                emit unexpectedFailureAssertionInPackageHandler(handlerContract, lowLevelData);
            }
        } else if (packageType == FAIL_ACK_PACKAGE) {
            address handlerContract = channelHandlerContractMap[channelIdLocal];
            try IMiddleLayer(handlerContract).handleFailAckPackage(channelIdLocal, msgBytes) {
            } catch Error(string memory reason) {
                emit unexpectedRevertInPackageHandler(handlerContract, reason);
            } catch (bytes memory lowLevelData) {
                emit unexpectedFailureAssertionInPackageHandler(handlerContract, lowLevelData);
            }
        }
//        IRelayerIncentivize(INCENTIVIZE_ADDR).addReward(headerRelayer, msg.sender, relayFee, isRelayRewardFromSystemReward[channelIdLocal] || packageType != SYN_PACKAGE);
    }

    function sendPackage(uint64 packageSequence, uint8 channelId, bytes memory payload) internal whenNotSuspended {
        if (block.number > previousTxHeight) {
            oracleSequence++;
            txCounter = 1;
            previousTxHeight=block.number;
        } else {
            txCounter++;
            if (txCounter>batchSizeForOracle) {
                oracleSequence++;
                txCounter = 1;
            }
        }
        emit CrossChainPackage(bscChainID, uint64(oracleSequence), packageSequence, channelId, payload);
    }

    function sendSynPackage(uint8 channelId, bytes calldata msgBytes, uint256 relayFee)
    onlyRegisteredContractChannel(channelId)
    external {
        uint64 sendSequence = channelSendSequenceMap[channelId];
        sendPackage(sendSequence, channelId, encodePayload(SYN_PACKAGE, relayFee, msgBytes));
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
            if (handlerContract != address(0x00)) { //channel existing
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
