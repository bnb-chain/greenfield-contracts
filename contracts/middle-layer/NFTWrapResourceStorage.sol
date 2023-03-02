// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "../Config.sol";

contract NFTWrapResourceStorage is Config {
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
    uint32 public constant AUTH_CODE_MIRROR = 0x00000001;
    uint32 public constant AUTH_CODE_CREATE = 0x00000010;
    uint32 public constant AUTH_CODE_DELETE = 0x00000100;

    // role
    bytes32 public constant ROLE_MIRROR = keccak256("ROLE_MIRROR");
    bytes32 public constant ROLE_CREATE = keccak256("ROLE_CREATE");
    bytes32 public constant ROLE_DELETE = keccak256("ROLE_DELETE");

    /*----------------- storage -----------------*/
    address public ERC721Token;
    address public additional;

    // struct CreateSynPackage should be defined in child contract

    // GNFD to BSC
    struct CmnCreateAckPackage {
        uint32 status;
        uint256 id;
        address creator;
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
        address owner;
    }

    // BSC to GNFD
    struct CmnMirrorAckPackage {
        uint32 status;
        uint256 id;
    }

    event MirrorSuccess(uint256 id, address owner);
    event MirrorFailed(uint256 id, address owner, bytes failReason);
    event CreateSubmitted(address owner, address operator, string name, uint256 relayFee, uint256 ackRelayFee);
    event CreateSuccess(address creator, uint256 id);
    event CreateFailed(address creator, uint256 id);
    event DeleteSubmitted(address operator, uint256 id, uint256 relayFee, uint256 ackRelayFee);
    event DeleteSuccess(uint256 id);
    event DeleteFailed(uint256 id);
    event FailAckPkgReceived(uint8 channelId, bytes msgBytes);
    event UnexpectedPackage(uint8 channelId, bytes msgBytes);
    event ParamChange(string key, bytes value);
}
