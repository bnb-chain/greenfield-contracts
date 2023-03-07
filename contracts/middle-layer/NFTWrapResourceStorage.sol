// SPDX-License-Identifier: Apache-2.0.

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

    /*----------------- storage -----------------*/
    address public ERC721Token;
    address public additional;

    // dApp info
    struct ExtraData {
        address appAddress;
        address refundAddress;
        FailureHandleStrategy failureHandleStrategy;
        bytes callbackData;
    }

    // struct CreateSynPackage should be defined in child contract

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

    // PlaceHolder reserve for future use
    uint256[50] public slots;

    event MirrorSuccess(uint256 id, address owner);
    event MirrorFailed(uint256 id, address owner, bytes failReason);
    event CreateSubmitted(address owner, address operator, string name, uint256 relayFee, uint256 ackRelayFee);
    event CreateSuccess(address creator, uint256 id);
    event CreateFailed(address creator, uint256 id);
    event DeleteSubmitted(address owner, address operator, uint256 id, uint256 relayFee, uint256 ackRelayFee);
    event DeleteSuccess(uint256 id);
    event DeleteFailed(uint256 id);
    event FailAckPkgReceived(uint8 channelId, bytes msgBytes);
    event UnexpectedPackage(uint8 channelId, bytes msgBytes);
    event ParamChange(string key, bytes value);

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
