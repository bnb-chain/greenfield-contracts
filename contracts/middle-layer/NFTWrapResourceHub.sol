// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./NFTWrapResourceStorage.sol";
import "../lib/BytesToTypes.sol";
import "../lib/Memory.sol";
import "../lib/RLPEncode.sol";
import "../lib/RLPDecode.sol";
import "../interface/IERC721NonTransferable.sol";
import "../interface/IAccessControl.sol";

abstract contract NFTWrapResourceHub is Initializable, NFTWrapResourceStorage {
    using RLPEncode for *;
    using RLPDecode for *;

    /*----------------- modifier -----------------*/
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

    /*----------------- external function -----------------*/

    function grant(address account, uint32 acCode, uint256 expireTime) external {
        delegateAdditional();
    }

    function revoke(address account, uint32 acCode) external {
        delegateAdditional();
    }

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
                ackPkg.id = iter.next().toUint();
            } else if (idx == 2) {
                ackPkg.creator = iter.next().toAddress();
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
        elements[1] = mirrorAckPkg.id.encodeUint();
        return _RLPEncode(TYPE_MIRROR, elements.encodeList());
    }

    function _handleMirrorSynPackage(bytes memory msgBytes) internal virtual returns (bytes memory) {
        (CmnMirrorSynPackage memory synPkg, bool success) = _decodeCmnMirrorSynPackage(msgBytes);
        require(success, "unrecognized mirror package");

        uint32 status = _doMirror(synPkg);
        CmnMirrorAckPackage memory mirrorAckPkg = CmnMirrorAckPackage({status: status, id: synPkg.id});
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

    function delegateAdditional() internal {
        address _target = additional;
        assembly {
            // The pointer to the free memory slot
            let ptr := mload(0x40)
            // Copy function signature and arguments from calldata at zero position into memory at pointer position
            calldatacopy(ptr, 0x0, calldatasize())
            // Delegatecall method of the implementation contract, returns 0 on error
            let result := delegatecall(gas(), _target, ptr, calldatasize(), 0x0, 0)
            // Get the size of the last return data
            let size := returndatasize()
            // Copy the size length of bytes from return data at zero position to pointer position
            returndatacopy(ptr, 0x0, size)

            // Depending on result value
            switch result
            case 0 {
                // End execution and revert state changes
                revert(ptr, size)
            }
            default {
                // Return data with length of size at pointers position
                return(ptr, size)
            }
        }
    }
}
