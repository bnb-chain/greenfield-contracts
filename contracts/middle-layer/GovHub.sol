// SPDX-License-Identifier: Apache-2.0.

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

    uint8 public constant ADDRESS_LENGTH = 20;
    uint8 public constant PARAM_UPDATE_MESSAGE_TYPE = 0;

    uint32 public constant CODE_OK = 0;
    uint32 public constant ERROR_FAIL_DECODE = 100;
    uint32 public constant ERROR_TARGET_NOT_CONTRACT = 101;
    uint32 public constant ERROR_TARGET_CONTRACT_FAIL = 102;
    uint32 public constant ERROR_INVALID_IMPLEMENTATION = 103;
    uint32 public constant ERROR_UPGRADE_FAIL = 104;

    bytes32 public constant UPGRADE_KEY_HASH = keccak256(abi.encodePacked("upgrade"));

    event SuccessUpgrade(address target, address newImplementation);
    event FailUpgrade(address newImplementation, bytes message);
    event FailUpdateParam(bytes message);
    event ParamChange(string key, bytes value);

    struct ParamChangePackage {
        string key;
        bytes values;
        bytes targets;
    }

    modifier onlyCrossChainContract() {
        require(msg.sender == CROSS_CHAIN, "only cross chain contract");
        _;
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
        require(proposal.targets.length > 0 && proposal.targets.length % ADDRESS_LENGTH == 0, "invalid target length");
        uint256 totalTargets = proposal.targets.length / ADDRESS_LENGTH;

        // upgrade contracts
        if (keccak256(abi.encodePacked(proposal.key)) == UPGRADE_KEY_HASH) {
            require(proposal.values.length == proposal.targets.length, "invalid values length");

            address target;
            address newImpl;
            for (uint256 i; i < totalTargets; ++i) {
                target = BytesToTypes.bytesToAddress(ADDRESS_LENGTH * (i + 1), proposal.targets);
                newImpl = BytesToTypes.bytesToAddress(ADDRESS_LENGTH * (i + 1), proposal.values);
                require(_isContract(target), "invalid target");
                require(_isContract(newImpl), "invalid implementation value");

                IProxyAdmin(PROXY_ADMIN).upgrade(target, newImpl);
                emit SuccessUpgrade(target, newImpl);
            }
            return CODE_OK;
        }

        // update param
        require(totalTargets == 1, "Only single parameter update is allowed in a proposal");
        address _target = BytesToTypes.bytesToAddress(ADDRESS_LENGTH, proposal.targets);
        try IParamSubscriber(_target).updateParam(proposal.key, proposal.values) {}
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
                pkg.values = iter.next().toBytes();
            } else if (idx == 2) {
                pkg.targets = iter.next().toBytes();
                success = true;
            } else {
                break;
            }
            idx++;
        }
        return (pkg, success);
    }
}
