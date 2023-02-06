pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interface/IMiddleLayer.sol";
import "./interface/IGovHub.sol";
import "./interface/ITokenHub.sol";
import "./interface/ILightClient.sol";
import "./interface/IRelayerHub.sol";
import "./lib/Memory.sol";
import "./lib/BytesToTypes.sol";
import "./Config.sol";
import "./Governance.sol";

contract CrossChain is Initializable, Config, Governance {
    // constant variables
    uint8 public constant SYN_PACKAGE = 0x00;
    uint8 public constant ACK_PACKAGE = 0x01;
    uint8 public constant FAIL_ACK_PACKAGE = 0x02;

    uint256 public constant IN_TURN_RELAYER_VALIDITY_PERIOD = 15 seconds;
    uint256 public constant OUT_TURN_RELAYER_BACKOFF_PERIOD = 3 seconds;

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
    mapping(uint8 => bool) public isRelayRewardFromSystemReward;

    // to prevent the utilization of ancient block header
    mapping(uint8 => uint64) public channelSyncedHeaderMap;

    // event
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

    function initialize(uint16 _gnfdChainId, address _govHub) public initializer {
        require(_gnfdChainId != 0, "zero _gnfdChainId");
        require(_govHub != address(0), "zero _govHub");

        chainId = uint16(block.chainid);
        gnfdChainId = _gnfdChainId;
        govHub = _govHub;

        // TODO register other channels
        address _tokenHub = IGovHub(_govHub).tokenHub();

        channelHandlerMap[TRANSFER_IN_CHANNELID] = _tokenHub;
        registeredContractChannelMap[_tokenHub][TRANSFER_IN_CHANNELID] = true;

        channelHandlerMap[TRANSFER_OUT_CHANNELID] = _tokenHub;
        registeredContractChannelMap[_tokenHub][TRANSFER_OUT_CHANNELID] = true;

        channelHandlerMap[GOV_CHANNELID] = _govHub;
        registeredContractChannelMap[_tokenHub][GOV_CHANNELID] = true;

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
        return
            packageType == SYN_PACKAGE
            ? abi.encodePacked(packageType, uint64(block.timestamp), relayFee, ackRelayFee, msgBytes)
            : abi.encodePacked(packageType, uint64(block.timestamp), relayFee, msgBytes);
    }

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
        address _lightClient = IGovHub(govHub).lightClient();
        _checkValidRelayer(eventTime, _lightClient);

        // 3. verify bls signature
        require(
            ILightClient(_lightClient).verifyPackage(_payload, _blsSignature, _validatorsBitSet),
            "cross-chain package not verified"
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
                    channelSendSequenceMap[channelId], channelId, encodePayload(FAIL_ACK_PACKAGE, ackRelayFee, 0, packageLoad)
                );
                channelSendSequenceMap[channelId] = channelSendSequenceMap[channelId] + 1;
                emit UnexpectedRevertInPackageHandler(_handler, reason);
            } catch (bytes memory lowLevelData) {
                _sendPackage(
                    channelSendSequenceMap[channelId], channelId, encodePayload(FAIL_ACK_PACKAGE, ackRelayFee, 0, packageLoad)
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

        address _relayerHub = IGovHub(govHub).relayerHub();
        IRelayerHub(_relayerHub).addReward(msg.sender, relayFee);
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
        emit CrossChainPackage(chainId, gnfdChainId, uint64(oracleSequence), packageSequence, channelId, payload);
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
}
