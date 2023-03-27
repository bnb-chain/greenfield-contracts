// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "./CmnStorage.sol";

contract GroupStorage is CmnStorage {
    /*----------------- constants -----------------*/
    // operation type
    uint8 public constant TYPE_UPDATE = 4;

    // update type
    uint8 public constant UPDATE_ADD = 1;
    uint8 public constant UPDATE_DELETE = 2;

    // authorization code
    uint32 public constant AUTH_CODE_UPDATE = 4; // 0100

    // role
    bytes32 public constant ROLE_UPDATE = keccak256("ROLE_UPDATE");

    // package type
    bytes32 public constant CREATE_GROUP_SYN = keccak256("CREATE_GROUP_SYN");
    bytes32 public constant UPDATE_GROUP_SYN = keccak256("UPDATE_GROUP_SYN");
    bytes32 public constant UPDATE_GROUP_ACK = keccak256("UPDATE_GROUP_ACK");

    /*----------------- storage -----------------*/
    address public ERC1155Token;

    // PlaceHolder reserve for future use
    uint256[25] public GroupStorageSlots;

    // BSC to GNFD
    struct CreateGroupSynPackage {
        address creator;
        string name;
        bytes extraData; // rlp encode of ExtraData
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

    event UpdateSubmitted(address owner, address operator, uint256 id, uint8 opType, address[] members);
    event UpdateSuccess(address indexed operator, uint256 indexed id, uint8 opType);
    event UpdateFailed(address indexed operator, uint256 indexed id, uint8 opType);
}
