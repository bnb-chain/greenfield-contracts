// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./Config.sol";
import "./lib/RLPEncode.sol";
import "./lib/RLPDecode.sol";
import "./lib/BytesToTypes.sol";
import "./lib/Memory.sol";
import "./interface/IERC721NonTransferable.sol";

abstract contract StorageHub is Initializable, Config {
    using RLPEncode for *;
    using RLPDecode for *;

    /*----------------- constants -----------------*/
    // res code
    uint8 public constant MIRROR_SUCCESS = 0;

    // status of ack package
    uint32 public constant STATUS_SUCCESS = 0;
    uint32 public constant STATUS_FAILED = 1;

    // operation type
    uint8 public constant TYPE_MIRROR = 1;

    /*----------------- storage layer -----------------*/
    uint256 public relayFee;
    uint256 public ackRelayFee;

    // ERC721 token contract
    address public _token;

    /*----------------- struct / event / modifier -----------------*/
    // GNFD to BSC
    struct CreateAckPackage {
        uint32 status;
        address creator;
        uint256 id;
    }

    // BSC to GNFD
    struct DeleteSynPackage {
        address operator;
        string name;
    }

    // GNFD to BSC
    struct DeleteAckPackage {
        uint32 status;
        uint256 id;
    }

    // GNFD to BSC
    struct MirrorSynPackage {
        uint256 id;
        bytes key;
        address owner;
    }

    // BSC to GNFD
    struct MirrorAckPackage {
        uint32 status;
        bytes key;
    }

    event MirrorSuccess(uint256 id, address owner);
    event CreateSubmitted(address creator, string name, uint256 relayFee, uint256 ackRelayFee);
    event CreateFailed(address creator, uint256 id);
    event CreateSuccess(address creator, uint256 id);
    event DeleteSubmitted(address operator, string name, uint256 relayFee, uint256 ackRelayFee);
    event DeleteFailed(uint256 id);
    event DeleteSuccess(uint256 id);
    event FailAckPkgReceived(uint8 channelId, bytes msgBytes);
    event UnexpectedPackage(uint8 channelId, bytes msgBytes);
    event ParamChange(string key, bytes value);

    modifier onlyCrossChainContract() {
        require(msg.sender == CROSS_CHAIN, "only CrossChain contract");
        _;
    }

    receive() external payable {}

    function initialize(address token_) public initializer {
        _token = token_;

        relayFee = 2e15;
        ackRelayFee = 2e15;
    }

    /*----------------- update param -----------------*/
    function updateParam(string calldata key, bytes calldata value) external {
        if (Memory.compareStrings(key, "baseURL")) {
            bytes memory newBaseURI;
            BytesToTypes.bytesToString(32, value, newBaseURI);
            IERC721NonTransferable(_token).setBaseURI(string(newBaseURI));
        } else {
            revert("unknown param");
        }
        emit ParamChange(key, value);
    }

    /*----------------- internal function -----------------*/
    function _decodeCreateAckPackage(RLPDecode.Iterator memory iter)
        internal
        pure
        returns (CreateAckPackage memory, bool)
    {
        CreateAckPackage memory ackPkg;

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

    function _handleCreateAckPackage(RLPDecode.Iterator memory iter) internal {
        (CreateAckPackage memory ackPkg, bool decodeSuccess) = _decodeCreateAckPackage(iter);
        require(decodeSuccess, "unrecognized create ack package");
        if (ackPkg.status == STATUS_SUCCESS) {
            _doCreate(ackPkg.creator, ackPkg.id);
        } else if (ackPkg.status == STATUS_FAILED) {
            emit CreateFailed(ackPkg.creator, ackPkg.id);
        } else {
            revert("unexpected status code");
        }
    }

    function _doCreate(address creator, uint256 id) internal {
        IERC721NonTransferable(_token).mint(creator, id);
        emit CreateSuccess(creator, id);
    }

    function _decodeDeleteAckPackage(RLPDecode.Iterator memory iter)
        internal
        pure
        returns (DeleteAckPackage memory, bool)
    {
        DeleteAckPackage memory ackPkg;

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

    function _handleDeleteAckPackage(RLPDecode.Iterator memory iter) internal {
        (DeleteAckPackage memory ackPkg, bool decodeSuccess) = _decodeDeleteAckPackage(iter);
        require(decodeSuccess, "unrecognized delete ack package");
        if (ackPkg.status == STATUS_SUCCESS) {
            _doDelete(ackPkg.id);
        } else if (ackPkg.status == STATUS_FAILED) {
            emit DeleteFailed(ackPkg.id);
        } else {
            revert("unexpected status code");
        }
    }

    function _doDelete(uint256 id) internal {
        IERC721NonTransferable(_token).burn(id);
        emit DeleteSuccess(id);
    }

    function _decodeMirrorSynPackage(bytes memory msgBytes) internal pure returns (MirrorSynPackage memory, bool) {
        MirrorSynPackage memory synPkg;

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

    function _encodeMirrorAckPackage(MirrorAckPackage memory mirrorAckPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](2);
        elements[0] = uint256(mirrorAckPkg.status).encodeUint();
        elements[1] = mirrorAckPkg.key.encodeBytes();
        return _RLPEncode(TYPE_MIRROR, elements.encodeList());
    }

    function _handleMirrorSynPackage(bytes memory msgBytes) internal returns (bytes memory) {
        (MirrorSynPackage memory synPkg, bool success) = _decodeMirrorSynPackage(msgBytes);
        require(success, "unrecognized mirror package");
        uint32 resCode = _doMirror(synPkg);
        MirrorAckPackage memory mirrorAckPkg = MirrorAckPackage({status: resCode, key: synPkg.key});
        return _encodeMirrorAckPackage(mirrorAckPkg);
    }

    function _doMirror(MirrorSynPackage memory synPkg) internal returns (uint32) {
        IERC721NonTransferable(_token).mint(synPkg.owner, synPkg.id);
        emit MirrorSuccess(synPkg.id, synPkg.owner);
        return MIRROR_SUCCESS;
    }

    function _RLPEncode(uint8 opType, bytes memory msgBytes) internal pure returns (bytes memory output) {
        bytes[] memory elements = new bytes[](2);
        elements[0] = opType.encodeUint();
        elements[1] = msgBytes.encodeBytes();
        output = elements.encodeList();
    }
}
