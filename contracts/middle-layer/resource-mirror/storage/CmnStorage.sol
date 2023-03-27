// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "../utils/PackageQueue.sol";
import "../../../Config.sol";

contract CmnStorage is Config, PackageQueue {
    /*----------------- constants -----------------*/
    // status of cross-chain package
    uint32 public constant STATUS_SUCCESS = 0;
    uint32 public constant STATUS_FAILED = 1;
    uint32 public constant STATUS_UNEXPECTED = 2;

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
    address public ERC721Token;
    address public additional;
    address public rlp;

    // PlaceHolder reserve for future use
    uint256[25] public CmnStorageSlots;

    // dApp info
    struct ExtraData {
        address appAddress;
        address refundAddress;
        FailureHandleStrategy failureHandleStrategy;
        bytes callbackData;
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

    event MirrorSuccess(uint256 indexed id, address indexed owner);
    event MirrorFailed(uint256 indexed id, address indexed owner, bytes failReason);
    event CreateSubmitted(address indexed owner, address indexed operator, string name);
    event CreateSuccess(address indexed creator, uint256 indexed id);
    event CreateFailed(address indexed creator, uint256 indexed id);
    event DeleteSubmitted(address indexed owner, address indexed operator, uint256 indexed id);
    event DeleteSuccess(uint256 indexed id);
    event DeleteFailed(uint256 indexed id);
    event FailAckPkgReceived(uint8 indexed channelId, bytes msgBytes);
    event UnexpectedPackage(uint8 indexed channelId, bytes msgBytes);
    event ParamChange(string key, bytes value);
}
