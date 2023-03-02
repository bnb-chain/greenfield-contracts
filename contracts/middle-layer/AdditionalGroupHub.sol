// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./AccessControl.sol";
import "./NFTWrapResourceStorage.sol";
import "../interface/ICrossChain.sol";
import "../interface/IERC721NonTransferable.sol";
import "../lib/RLPDecode.sol";
import "../lib/RLPEncode.sol";

contract AdditionalGroupHub is Initializable, NFTWrapResourceStorage, AccessControl {
    using RLPEncode for *;
    using RLPDecode for *;

    /*----------------- constants -----------------*/
    // operation type
    uint8 public constant TYPE_UPDATE = 4;

    // update type
    uint8 public constant UPDATE_ADD = 1;
    uint8 public constant UPDATE_DELETE = 2;

    // authorization code
    uint32 public constant AUTH_CODE_UPDATE = 0x00001000;

    // role
    bytes32 public ROLE_UPDATE;

    // ERC1155 token contract
    address public ERC1155Token;

    /*----------------- struct / event -----------------*/
    // BSC to GNFD
    struct CreateSynPackage {
        address creator;
        string name;
        address[] members;
    }

    struct UpdateSynPackage {
        address operator;
        uint256 id; // group id
        uint8 opType; // add/remove members
        address[] members;
    }

    // GNFD to BSC
    struct UpdateAckPackage {
        uint32 status;
        address operator;
        uint256 id; // group id
        uint8 opType; // add/remove members
        address[] members;
    }

    event UpdateSubmitted(
        address owner,
        address operator,
        uint256 id,
        uint8 opType,
        address[] members,
        uint256 relayFee,
        uint256 ackRelayFee
    );
    event UpdateSuccess(address operator, uint256 id, uint8 opType);
    event UpdateFailed(address operator, uint256 id, uint8 opType);

    function grant(address account, uint32 acCode, uint256 expireTime) external {
        if (expireTime == 0) {
            expireTime = block.timestamp + 30 days; // 30 days in default
        }

        if (acCode & AUTH_CODE_MIRROR != 0) {
            acCode = acCode & ~AUTH_CODE_MIRROR;
            grantRole(ROLE_MIRROR, account, expireTime);
        }
        if (acCode & AUTH_CODE_CREATE != 0) {
            acCode = acCode & ~AUTH_CODE_CREATE;
            grantRole(ROLE_CREATE, account, expireTime);
        }
        if (acCode & AUTH_CODE_DELETE != 0) {
            acCode = acCode & ~AUTH_CODE_DELETE;
            grantRole(ROLE_DELETE, account, expireTime);
        }
        if (acCode & AUTH_CODE_UPDATE != 0) {
            acCode = acCode & ~AUTH_CODE_UPDATE;
            grantRole(ROLE_UPDATE, account, expireTime);
        }

        require(acCode == 0, "invalid authorization code");
    }

    function revoke(address account, uint32 acCode) external {
        if (acCode & AUTH_CODE_MIRROR != 0) {
            acCode = acCode & ~AUTH_CODE_MIRROR;
            revokeRole(ROLE_MIRROR, account);
        }
        if (acCode & AUTH_CODE_CREATE != 0) {
            acCode = acCode & ~AUTH_CODE_CREATE;
            revokeRole(ROLE_CREATE, account);
        }
        if (acCode & AUTH_CODE_DELETE != 0) {
            acCode = acCode & ~AUTH_CODE_DELETE;
            revokeRole(ROLE_DELETE, account);
        }
        if (acCode & AUTH_CODE_UPDATE != 0) {
            acCode = acCode & ~AUTH_CODE_DELETE;
            revokeRole(ROLE_UPDATE, account);
        }

        require(acCode == 0, "invalid authorization code");
    }

    /**
     * @dev create a group and send cross-chain request from BSC to GNFD
     *
     * @param owner The group's owner
     * @param name The group's name
     * @param members The initial members of the group
     */
    function createGroup(address owner, string memory name, address[] memory members) external payable returns (bool) {
        require(msg.value >= relayFee + ackRelayFee, "received BNB amount should be no less than the minimum relayFee");
        uint256 _ackRelayFee = msg.value - relayFee;

        // check authorization
        if (msg.sender != owner) {
            require(hasRole(ROLE_CREATE, owner, msg.sender), "no permission to create");
        }

        CreateSynPackage memory synPkg = CreateSynPackage({creator: owner, name: name, members: members});

        address _crossChain = CROSS_CHAIN;
        ICrossChain(_crossChain).sendSynPackage(
            GROUP_CHANNEL_ID, _encodeCreateSynPackage(synPkg), relayFee, _ackRelayFee
        );
        emit CreateSubmitted(owner, msg.sender, name, relayFee, _ackRelayFee);
        return true;
    }

    /**
     * @dev delete a group and send cross-chain request from BSC to GNFD
     *
     * @param id The group's id
     */
    function deleteGroup(uint256 id) external payable returns (bool) {
        require(msg.value >= relayFee + ackRelayFee, "received BNB amount should be no less than the minimum relayFee");
        uint256 _ackRelayFee = msg.value - relayFee;

        // check authorization
        address owner = IERC721NonTransferable(ERC721Token).ownerOf(id);
        if (
            !(
                msg.sender == owner || IERC721NonTransferable(ERC721Token).getApproved(id) == msg.sender
                    || IERC721NonTransferable(ERC721Token).isApprovedForAll(owner, msg.sender)
            )
        ) {
            require(hasRole(ROLE_DELETE, owner, msg.sender), "no delete permission");
        }

        CmnDeleteSynPackage memory synPkg = CmnDeleteSynPackage({operator: owner, id: id});

        address _crossChain = CROSS_CHAIN;
        ICrossChain(_crossChain).sendSynPackage(
            GROUP_CHANNEL_ID, _encodeCmnDeleteSynPackage(synPkg), relayFee, _ackRelayFee
        );
        emit DeleteSubmitted(owner, msg.sender, id, relayFee, _ackRelayFee);
        return true;
    }

    /**
     * @dev update a group's member and send cross-chain request from BSC to GNFD
     *
     * @param synPkg Package containing information of the group to be updated
     */
    function updateGroup(UpdateSynPackage memory synPkg) external payable returns (bool) {
        require(msg.value >= relayFee + ackRelayFee, "received BNB amount should be no less than the minimum relayFee");
        uint256 _ackRelayFee = msg.value - relayFee;

        // check authorization
        address owner = IERC721NonTransferable(ERC721Token).ownerOf(synPkg.id);
        if (
            !(
                msg.sender == owner || IERC721NonTransferable(ERC721Token).getApproved(synPkg.id) == msg.sender
                    || IERC721NonTransferable(ERC721Token).isApprovedForAll(owner, msg.sender)
            )
        ) {
            require(hasRole(ROLE_UPDATE, owner, msg.sender), "no update permission");
        }

        address _crossChain = CROSS_CHAIN;
        ICrossChain(_crossChain).sendSynPackage(
            GROUP_CHANNEL_ID, _encodeUpdateSynPackage(synPkg), relayFee, _ackRelayFee
        );
        emit UpdateSubmitted(owner, msg.sender, synPkg.id, synPkg.opType, synPkg.members, relayFee, _ackRelayFee);
        return true;
    }

    /*----------------- internal function -----------------*/
    function _encodeCreateSynPackage(CreateSynPackage memory synPkg) internal pure returns (bytes memory) {
        bytes[] memory members = new bytes[](synPkg.members.length);
        for (uint256 i; i < synPkg.members.length; ++i) {
            members[i] = synPkg.members[i].encodeAddress();
        }

        bytes[] memory elements = new bytes[](3);
        elements[0] = synPkg.creator.encodeAddress();
        elements[1] = bytes(synPkg.name).encodeBytes();
        elements[2] = members.encodeList();
        return _RLPEncode(TYPE_CREATE, elements.encodeList());
    }

    function _encodeCmnDeleteSynPackage(CmnDeleteSynPackage memory synPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](2);
        elements[0] = synPkg.operator.encodeAddress();
        elements[1] = synPkg.id.encodeUint();
        return _RLPEncode(TYPE_DELETE, elements.encodeList());
    }

    function _encodeUpdateSynPackage(UpdateSynPackage memory synPkg) internal pure returns (bytes memory) {
        bytes[] memory members = new bytes[](synPkg.members.length);
        for (uint256 i; i < synPkg.members.length; ++i) {
            members[i] = synPkg.members[i].encodeAddress();
        }

        bytes[] memory elements = new bytes[](4);
        elements[0] = synPkg.operator.encodeAddress();
        elements[1] = synPkg.id.encodeUint();
        elements[2] = uint256(synPkg.opType).encodeUint();
        elements[3] = members.encodeList();
        return _RLPEncode(TYPE_UPDATE, elements.encodeList());
    }

    function _RLPEncode(uint8 opType, bytes memory msgBytes) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](2);
        elements[0] = opType.encodeUint();
        elements[1] = msgBytes.encodeBytes();
        return elements.encodeList();
    }
}
