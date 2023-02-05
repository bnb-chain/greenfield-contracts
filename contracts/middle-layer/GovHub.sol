pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../interface/IParamSubscriber.sol";
import "../interface/IProxyAdmin.sol";
import "../lib/BytesToTypes.sol";
import "../lib/Memory.sol";
import "../lib/CmnPkg.sol";

import "../lib/RLPDecode.sol";
import "../Config.sol";

contract GovHub is Config, Initializable {
    using RLPDecode for *;

    uint8 public constant PARAM_UPDATE_MESSAGE_TYPE = 0;

    uint32 public constant ERROR_TARGET_NOT_CONTRACT = 101;
    uint32 public constant ERROR_TARGET_CONTRACT_FAIL = 102;
    uint32 public constant ERROR_INVALID_IMPLEMENTATION = 103;
    uint32 public constant ERROR_UPGRADE_FAIL = 104;

    bytes32 public constant UPGRADE_KEY_HASH = keccak256(abi.encodePacked("upgrade"));

    // all inscription contract address
    address public proxyAdmin;

    address public crosschain;
    address public tokenHub;
    address public lightClient;
    address public relayerHub;

    event FailUpgrade(address newImplementation, bytes message);
    event FailUpdateParam(bytes message);
    event ParamChange(string key, bytes value);

    struct ParamChangePackage {
        string key;
        bytes value;
        address target;
    }

    modifier onlyCrossChainContract() {
        require(msg.sender == crosschain, "only cross chain contract");
        _;
    }

    function initialize(
        address _proxyAdmin,
        address _crosschain,
        address _tokenHub,
        address _lightClient,
        address _relayerHub
    )
        public
        initializer
    {
        require(_proxyAdmin != address(0), "zero _proxyAdmin");
        require(_crosschain != address(0), "zero _crosschain");
        require(_tokenHub != address(0), "zero _tokenHub");
        require(_lightClient != address(0), "zero _lightClient");
        require(_relayerHub != address(0), "zero _relayerHub");

        proxyAdmin = _proxyAdmin;
        crosschain = _crosschain;
        tokenHub = _tokenHub;
        lightClient = _lightClient;
        relayerHub = _relayerHub;
    }

    function handleSynPackage(uint8, bytes calldata msgBytes)
        external
        onlyCrossChainContract
        returns (bytes memory responsePayload)
    {
        (ParamChangePackage memory proposal, bool success) = _decodeSynPackage(msgBytes);
        if (!success) {
            return CmnPkg.encodeCommonAckPackage(ERROR_FAIL_DECODE);
        }
        uint32 resCode = _notifyUpdates(proposal);
        if (resCode == CODE_OK) {
            return new bytes(0);
        } else {
            return CmnPkg.encodeCommonAckPackage(resCode);
        }
    }

    // should not happen
    function handleAckPackage(uint8, bytes calldata) external view onlyCrossChainContract {
        revert("receive unexpected ack package");
    }

    // should not happen
    function handleFailAckPackage(uint8, bytes calldata) external view onlyCrossChainContract {
        revert("receive unexpected fail ack package");
    }

    function _notifyUpdates(ParamChangePackage memory proposal) internal returns (uint32) {
        if (!_isContract(proposal.target)) {
            emit FailUpdateParam("the target is not a contract");
            return ERROR_TARGET_NOT_CONTRACT;
        }

        // upgrade contract
        if (keccak256(abi.encodePacked(proposal.key)) == UPGRADE_KEY_HASH) {
            if (proposal.value.length != 20) {
                emit FailUpgrade(address(0), "invalid implementation value length");
                return ERROR_INVALID_IMPLEMENTATION;
            }

            address newImpl = BytesToTypes.bytesToAddress(20, proposal.value);
            if (!_isContract(newImpl)) {
                emit FailUpgrade(newImpl, "invalid implementation value");
                return ERROR_INVALID_IMPLEMENTATION;
            }

            try IProxyAdmin(proxyAdmin).upgrade(proposal.target, newImpl) {}
            catch (bytes memory reason) {
                emit FailUpgrade(newImpl, reason);
                return ERROR_UPGRADE_FAIL;
            }
            return CODE_OK;
        }

        // update params
        try IParamSubscriber(proposal.target).updateParam(proposal.key, proposal.value) {}
        catch (bytes memory reason) {
            emit FailUpdateParam(reason);
            return ERROR_TARGET_CONTRACT_FAIL;
        }
        return CODE_OK;
    }

    //rlp encode & decode function
    function _decodeSynPackage(bytes memory msgBytes) internal pure returns (ParamChangePackage memory, bool) {
        ParamChangePackage memory pkg;

        RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
        bool success = false;
        uint256 idx = 0;
        while (iter.hasNext()) {
            if (idx == 0) {
                pkg.key = string(iter.next().toBytes());
            } else if (idx == 1) {
                pkg.value = iter.next().toBytes();
            } else if (idx == 2) {
                pkg.target = iter.next().toAddress();
                success = true;
            } else {
                break;
            }
            idx++;
        }
        return (pkg, success);
    }

    function _isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.
        return account.code.length > 0;
    }
}
