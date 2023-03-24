// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "../Config.sol";
import "../PackageQueue.sol";
import "../lib/RLPDecode.sol";
import "../lib/RLPEncode.sol";

contract NFTWrapResourceStorage is Config, PackageQueue {
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

    // authorization code
    // can be used by bit operations
    uint32 public constant AUTH_CODE_CREATE = 1; // 0001
    uint32 public constant AUTH_CODE_DELETE = 2; // 0010

    // role
    bytes32 public constant ROLE_CREATE = keccak256("ROLE_CREATE");
    bytes32 public constant ROLE_DELETE = keccak256("ROLE_DELETE");

    // package type
    bytes32 public constant CMN_CREATE_ACK = keccak256("CMN_CREATE_ACK");
    bytes32 public constant CMN_DELETE_SYN = keccak256("CMN_DELETE_SYN");
    bytes32 public constant CMN_DELETE_ACK = keccak256("CMN_DELETE_ACK");

    /*----------------- storage -----------------*/
    uint8 public channelId;

    address public ERC721Token;
    address public additional;

    // dApp info
    struct ExtraData {
        address appAddress;
        address refundAddress;
        FailureHandleStrategy failureHandleStrategy;
        bytes callbackData;
    }

    // BSC to GNFD
    struct CreateBucketSynPackage {
        address creator;
        string name;
        BucketVisibilityType visibility;
        address paymentAddress;
        address primarySpAddress;
        uint256 primarySpApprovalExpiredHeight;
        bytes primarySpSignature; // TODO if the owner of the bucket is a smart contract, we are not able to get the primarySpSignature
        uint64 chargedReadQuota;
        bytes extraData; // rlp encode of ExtraData
    }

    enum BucketVisibilityType {
        PublicRead,
        Private,
        Default // If the bucket Visibility is default, it's finally set to private.
    }

    // BSC to GNFD
    struct CreateGroupSynPackage {
        address creator;
        string name;
        bytes extraData; // rlp encode of ExtraData
    }

    // GNFD to BSC
    struct CmnCreateAckPackage {
        uint32 status;
        uint256 id;
        address creator;
        bytes extraData; // rlp encode of ExtraData
    }

    // BSC to GNFD
    struct CmnDeleteSynPackage {
        address operator;
        uint256 id;
        bytes extraData; // rlp encode of ExtraData
    }

    // GNFD to BSC
    struct CmnDeleteAckPackage {
        uint32 status;
        uint256 id;
        bytes extraData; // rlp encode of ExtraData
    }

    // GNFD to BSC
    struct CmnMirrorSynPackage {
        uint256 id; // resource ID
        address owner;
    }

    // BSC to GNFD
    struct CmnMirrorAckPackage {
        uint32 status;
        uint256 id;
    }

    struct UpdateGroupSynPackage {
        address operator;
        uint256 id; // group id
        uint8 opType; // add/remove members
        address[] members;
        bytes extraData; // rlp encode of ExtraData
    }

    // GNFD to BSC
    struct UpdateGroupAckPackage {
        uint32 status;
        uint256 id; // group id
        address operator;
        uint8 opType; // add/remove members
        address[] members;
        bytes extraData; // rlp encode of ExtraData
    }

    // PlaceHolder reserve for future use
    uint256[50] public NFTWrapResourceStorageSlots;

    event MirrorSuccess(uint256 indexed id, address indexed owner);
    event MirrorFailed(uint256 indexed id, address indexed owner, bytes failReason);
    event CreateSubmitted(address indexed owner, address indexed operator, string name);
    event CreateSuccess(address indexed creator, uint256 indexed id);
    event CreateFailed(address indexed creator, uint256 indexed id);
    event DeleteSubmitted(address indexed owner, address indexed operator, uint256 indexed id);
    event DeleteSuccess(uint256 indexed id);
    event DeleteFailed(uint256 indexed id);
    event UpdateSubmitted(address owner, address operator, uint256 id, uint8 opType, address[] members);
    event UpdateSuccess(address indexed operator, uint256 indexed id, uint8 opType);
    event UpdateFailed(address indexed operator, uint256 indexed id, uint8 opType);
    event FailAckPkgReceived(uint8 indexed channelId, bytes msgBytes);
    event UnexpectedPackage(uint8 indexed channelId, bytes msgBytes);
    event ParamChange(string key, bytes value);

    function _decodeCmnCreateAckPackage(bytes memory pkgBytes)
        internal
        pure
        returns (CmnCreateAckPackage memory, bool)
    {
        CmnCreateAckPackage memory ackPkg;
        RLPDecode.Iterator memory iter = pkgBytes.toRLPItem().iterator();

        bool success;
        uint256 idx;
        while (iter.hasNext()) {
            if (idx == 0) {
                ackPkg.status = uint32(iter.next().toUint());
            } else if (idx == 1) {
                ackPkg.id = iter.next().toUint();
            } else if (idx == 2) {
                ackPkg.creator = iter.next().toAddress();
            } else if (idx == 3) {
                ackPkg.extraData = iter.next().toBytes();
                success = true;
            } else {
                break;
            }
            idx++;
        }
        return (ackPkg, success);
    }

    function _decodeCmnDeleteSynPackage(bytes memory pkgBytes)
        internal
        pure
        returns (CmnDeleteSynPackage memory, bool success)
    {
        CmnDeleteSynPackage memory synPkg;
        RLPDecode.Iterator memory iter = pkgBytes.toRLPItem().iterator();

        uint256 idx;
        while (iter.hasNext()) {
            if (idx == 0) {
                synPkg.operator = iter.next().toAddress();
            } else if (idx == 1) {
                synPkg.id = iter.next().toUint();
            } else if (idx == 2) {
                synPkg.extraData = iter.next().toBytes();
                success = true;
            } else {
                break;
            }
            idx++;
        }
        return (synPkg, success);
    }

    function _decodeCmnDeleteAckPackage(bytes memory pkgBytes)
        internal
        pure
        returns (CmnDeleteAckPackage memory, bool success)
    {
        CmnDeleteAckPackage memory ackPkg;
        RLPDecode.Iterator memory iter = pkgBytes.toRLPItem().iterator();

        uint256 idx;
        while (iter.hasNext()) {
            if (idx == 0) {
                ackPkg.status = uint32(iter.next().toUint());
            } else if (idx == 1) {
                ackPkg.id = iter.next().toUint();
            } else if (idx == 2) {
                ackPkg.extraData = iter.next().toBytes();
                success = true;
            } else {
                break;
            }
            idx++;
        }
        return (ackPkg, success);
    }

    function _extraDataToBytes(ExtraData memory _extraData) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](4);
        elements[0] = _extraData.appAddress.encodeAddress();
        elements[1] = _extraData.refundAddress.encodeAddress();
        elements[2] = uint256(_extraData.failureHandleStrategy).encodeUint();
        elements[3] = _extraData.callbackData.encodeBytes();
        return elements.encodeList();
    }

    function _RLPEncode(uint8 opType, bytes memory msgBytes) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](2);
        elements[0] = opType.encodeUint();
        elements[1] = msgBytes.encodeBytes();
        return elements.encodeList();
    }
}
