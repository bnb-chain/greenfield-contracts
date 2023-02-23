// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../Config.sol";
import "../lib/RLPEncode.sol";
import "../lib/RLPDecode.sol";
import "../lib/BytesToTypes.sol";
import "../lib/Memory.sol";
import "../interface/IERC721NonTransferable.sol";

abstract contract NFTWrapResourceHub is Initializable, Config {
    using RLPEncode for *;
    using RLPDecode for *;

    /*----------------- constants -----------------*/
    // status of cross-chain package
    uint32 public constant STATUS_SUCCESS = 0;
    uint32 public constant STATUS_FAILED = 1;

    // operation type
    uint8 public constant TYPE_MIRROR = 1;
    uint8 public constant TYPE_CREATE = 2;
    uint8 public constant TYPE_DELETE = 3;

    // ERC721 token contract
    address public ERC721Token;

    /*----------------- struct / event / modifier -----------------*/
    // struct CreateSynPackage should be defined in child contract

    // GNFD to BSC
    struct CmnCreateAckPackage {
        uint32 status;
        address creator;
        uint256 id;
    }

    // BSC to GNFD
    struct CmnDeleteSynPackage {
        address operator;
        uint256 id;
    }

    // GNFD to BSC
    struct CmnDeleteAckPackage {
        uint32 status;
        uint256 id;
    }

    // GNFD to BSC
    struct CmnMirrorSynPackage {
        uint256 id; // resource ID
        bytes key; // resource store key
        address owner;
    }

    // BSC to GNFD
    struct CmnMirrorAckPackage {
        uint32 status;
        bytes key;
    }

    event MirrorSuccess(uint256 id, address owner);
    event MirrorFailed(uint256 id, address owner, bytes failReason);
    event CreateSubmitted(address creator, string name, uint256 relayFee, uint256 ackRelayFee);
    event CreateFailed(address creator, uint256 id);
    event CreateSuccess(address creator, uint256 id);
    event DeleteSubmitted(address operator, uint256 id, uint256 relayFee, uint256 ackRelayFee);
    event DeleteFailed(uint256 id);
    event DeleteSuccess(uint256 id);
    event FailAckPkgReceived(uint8 channelId, bytes msgBytes);
    event UnexpectedPackage(uint8 channelId, bytes msgBytes);
    event ParamChange(string key, bytes value);

    modifier onlyCrossChainContract() {
        require(msg.sender == CROSS_CHAIN, "only CrossChain contract");
        _;
    }

    modifier onlyGovHub() {
        require(msg.sender == GOV_HUB, "only GovHub contract");
        _;
    }

    /*----------------- middle-layer app function -----------------*/

    // need to be implemented in child contract
    function handleSynPackage(uint8, bytes calldata) external virtual returns (bytes memory) {}

    function handleAckPackage(uint8, bytes calldata) external virtual {}

    function handleFailAckPackage(uint8 channelId, bytes calldata) external virtual {}

    /*----------------- update param -----------------*/
    function updateParam(string calldata key, bytes calldata value) external virtual onlyGovHub {
        if (Memory.compareStrings(key, "BaseURI")) {
            IERC721NonTransferable(ERC721Token).setBaseURI(string(value));
        } else {
            revert("unknown param");
        }
        emit ParamChange(key, value);
    }

    /*----------------- internal function -----------------*/
    function _decodeCmnCreateAckPackage(RLPDecode.Iterator memory iter)
        internal
        pure
        returns (CmnCreateAckPackage memory, bool)
    {
        CmnCreateAckPackage memory ackPkg;

        bool success = false;
        uint256 idx = 0;
        while (iter.hasNext()) {
            if (idx == 0) {
                ackPkg.status = uint32(iter.next().toUint());
            } else if (idx == 1) {
                ackPkg.creator = iter.next().toAddress();
            } else if (idx == 2) {
                ackPkg.id = iter.next().toUint();
                success = true;
            } else {
                break;
            }
            idx++;
        }
        return (ackPkg, success);
    }

    function _handleCreateAckPackage(RLPDecode.Iterator memory iter) internal virtual {
        (CmnCreateAckPackage memory ackPkg, bool success) = _decodeCmnCreateAckPackage(iter);
        require(success, "unrecognized create ack package");

        if (ackPkg.status == STATUS_SUCCESS) {
            _doCreate(ackPkg.creator, ackPkg.id);
        } else if (ackPkg.status == STATUS_FAILED) {
            emit CreateFailed(ackPkg.creator, ackPkg.id);
        } else {
            revert("unexpected status code");
        }
    }

    function _doCreate(address creator, uint256 id) internal virtual {
        IERC721NonTransferable(ERC721Token).mint(creator, id);
        emit CreateSuccess(creator, id);
    }

    function _decodeCmnDeleteAckPackage(RLPDecode.Iterator memory iter)
        internal
        pure
        returns (CmnDeleteAckPackage memory, bool)
    {
        CmnDeleteAckPackage memory ackPkg;

        bool success = false;
        uint256 idx = 0;
        while (iter.hasNext()) {
            if (idx == 0) {
                ackPkg.status = uint32(iter.next().toUint());
            } else if (idx == 1) {
                ackPkg.id = iter.next().toUint();
                success = true;
            } else {
                break;
            }
            idx++;
        }
        return (ackPkg, success);
    }

    function _handleDeleteAckPackage(RLPDecode.Iterator memory iter) internal virtual {
        (CmnDeleteAckPackage memory ackPkg, bool success) = _decodeCmnDeleteAckPackage(iter);
        require(success, "unrecognized delete ack package");

        if (ackPkg.status == STATUS_SUCCESS) {
            _doDelete(ackPkg.id);
        } else if (ackPkg.status == STATUS_FAILED) {
            emit DeleteFailed(ackPkg.id);
        } else {
            revert("unexpected status code");
        }
    }

    function _doDelete(uint256 id) internal virtual {
        IERC721NonTransferable(ERC721Token).burn(id);
        emit DeleteSuccess(id);
    }

    function _decodeCmnMirrorSynPackage(bytes memory msgBytes)
        internal
        pure
        returns (CmnMirrorSynPackage memory, bool)
    {
        CmnMirrorSynPackage memory synPkg;

        RLPDecode.Iterator memory msgIter = msgBytes.toRLPItem().iterator();
        uint8 opType = uint8(msgIter.next().toUint());
        require(opType == TYPE_MIRROR, "wrong syn operation type");

        RLPDecode.Iterator memory pkgIter;
        if (msgIter.hasNext()) {
            pkgIter = msgIter.next().toBytes().toRLPItem().iterator();
        } else {
            revert("wrong syn package");
        }

        bool success = false;
        uint256 idx = 0;
        while (pkgIter.hasNext()) {
            if (idx == 0) {
                synPkg.id = pkgIter.next().toUint();
            } else if (idx == 1) {
                synPkg.key = pkgIter.next().toBytes();
            } else if (idx == 2) {
                synPkg.owner = pkgIter.next().toAddress();
                success = true;
            } else {
                break;
            }
            idx++;
        }
        return (synPkg, success);
    }

    function _encodeCmnMirrorAckPackage(CmnMirrorAckPackage memory mirrorAckPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](2);
        elements[0] = uint256(mirrorAckPkg.status).encodeUint();
        elements[1] = mirrorAckPkg.key.encodeBytes();
        return _RLPEncode(TYPE_MIRROR, elements.encodeList());
    }

    function _handleMirrorSynPackage(bytes memory msgBytes) internal virtual returns (bytes memory) {
        (CmnMirrorSynPackage memory synPkg, bool success) = _decodeCmnMirrorSynPackage(msgBytes);
        require(success, "unrecognized mirror package");

        uint32 status = _doMirror(synPkg);
        CmnMirrorAckPackage memory mirrorAckPkg = CmnMirrorAckPackage({status: status, key: synPkg.key});
        return _encodeCmnMirrorAckPackage(mirrorAckPkg);
    }

    function _doMirror(CmnMirrorSynPackage memory synPkg) internal virtual returns (uint32) {
        try IERC721NonTransferable(ERC721Token).mint(synPkg.owner, synPkg.id) {}
        catch (bytes memory reason) {
            emit MirrorFailed(synPkg.id, synPkg.owner, reason);
            return STATUS_FAILED;
        }
        emit MirrorSuccess(synPkg.id, synPkg.owner);
        return STATUS_SUCCESS;
    }

    function _RLPEncode(uint8 opType, bytes memory msgBytes) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](2);
        elements[0] = opType.encodeUint();
        elements[1] = msgBytes.encodeBytes();
        return elements.encodeList();
    }
}
