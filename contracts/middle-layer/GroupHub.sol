// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "./NFTWrapResourceHub.sol";
import "../interface/IERC721NonTransferable.sol";
import "../interface/IERC1155NonTransferable.sol";
import "../interface/ICrossChain.sol";
import "../lib/RLPEncode.sol";
import "../lib/RLPDecode.sol";

contract GroupHub is NFTWrapResourceHub {
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
    bytes32 public constant ROLE_UPDATE = keccak256("ROLE_UPDATE");

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
        address operator, uint256 id, uint8 opType, address[] members, uint256 relayFee, uint256 ackRelayFee
    );
    event UpdateFailed(address operator, uint256 id, uint8 opType);
    event UpdateSuccess(address operator, uint256 id, uint8 opType);

    function initialize(address _ERC721_token, address _ERC1155_token) public initializer {
        ERC721Token = _ERC721_token;
        ERC1155Token = _ERC1155_token;

        relayFee = 2e15;
        ackRelayFee = 2e15;
    }

    /*----------------- middle-layer app function -----------------*/

    /**
     * @dev handle sync cross-chain package from BSC to GNFD
     *
     * @param msgBytes The rlp encoded message bytes sent from BSC to GNFD
     */
    function handleSynPackage(uint8, bytes calldata msgBytes)
        external
        override
        onlyCrossChainContract
        returns (bytes memory)
    {
        return _handleMirrorSynPackage(msgBytes);
    }

    /**
     * @dev handle ack cross-chain package from GNFD，it means create/delete operation Successly to GNFD.
     *
     * @param msgBytes The rlp encoded message bytes sent from GNFD
     */
    function handleAckPackage(uint8, bytes calldata msgBytes) external override onlyCrossChainContract {
        RLPDecode.Iterator memory msgIter = msgBytes.toRLPItem().iterator();

        uint8 opType = uint8(msgIter.next().toUint());
        RLPDecode.Iterator memory pkgIter;
        if (msgIter.hasNext()) {
            pkgIter = msgIter.next().toBytes().toRLPItem().iterator();
        } else {
            revert("wrong ack package");
        }

        if (opType == TYPE_CREATE) {
            _handleCreateAckPackage(pkgIter);
        } else if (opType == TYPE_DELETE) {
            _handleDeleteAckPackage(pkgIter);
        } else if (opType == TYPE_UPDATE) {
            _handleUpdateAckPackage(pkgIter);
        } else {
            revert("unexpected operation type");
        }
    }

    /**
     * @dev handle failed ack cross-chain package from GNFD, it means failed to cross-chain syn request to GNFD.
     *
     * @param msgBytes The rlp encoded message bytes sent from GNFD
     */
    function handleFailAckPackage(uint8 channelId, bytes calldata msgBytes) external override onlyCrossChainContract {
        emit FailAckPkgReceived(channelId, msgBytes);
    }

    /*----------------- external function -----------------*/
    /**
     * @dev create a group and send cross-chain request from BSC to GNFD
     *
     * @param owner The group's owner
     * @param name The group's name
     * @param members The initial members of the group
     */
    function createGroup(address owner, string calldata name, address[] calldata members)
        external
        payable
        returns (bool)
    {
        require(msg.value >= relayFee + ackRelayFee, "received BNB amount should be no less than the minimum relayFee");
        uint256 _ackRelayFee = msg.value - relayFee;

        // check authorization
        if (_msgSender() != owner) {
            _checkRole(AUTH_CODE_CREATE, owner);
        }

        CreateSynPackage memory synPkg = CreateSynPackage({creator: owner, name: name, members: members});

        address _crossChain = CROSS_CHAIN;
        ICrossChain(_crossChain).sendSynPackage(
            GROUP_CHANNEL_ID, _encodeCreateSynPackage(synPkg), relayFee, _ackRelayFee
        );
        emit CreateSubmitted(owner, _msgSender(), name, relayFee, _ackRelayFee);
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
                _msgSender() == owner || IERC721NonTransferable(ERC721Token).getApproved(id) == _msgSender()
                    || IERC721NonTransferable(ERC721Token).isApprovedForAll(owner, _msgSender())
            )
        ) {
            _checkRole(AUTH_CODE_DELETE, owner);
        }

        CmnDeleteSynPackage memory synPkg = CmnDeleteSynPackage({operator: owner, id: id});

        address _crossChain = CROSS_CHAIN;
        ICrossChain(_crossChain).sendSynPackage(
            GROUP_CHANNEL_ID, _encodeCmnDeleteSynPackage(synPkg), relayFee, _ackRelayFee
        );
        emit DeleteSubmitted(msg.sender, id, relayFee, _ackRelayFee);
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
                _msgSender() == owner || IERC721NonTransferable(ERC721Token).getApproved(id) == _msgSender()
                    || IERC721NonTransferable(ERC721Token).isApprovedForAll(owner, _msgSender())
            )
        ) {
            _checkRole(AUTH_CODE_UPDATE, owner);
        }

        address _crossChain = CROSS_CHAIN;
        ICrossChain(_crossChain).sendSynPackage(
            GROUP_CHANNEL_ID, _encodeUpdateSynPackage(synPkg), relayFee, _ackRelayFee
        );
        emit UpdateSubmitted(msg.sender, synPkg.id, synPkg.opType, synPkg.members, relayFee, _ackRelayFee);
        return true;
    }

    function grant(address account, uint32 acCode, uint256 expireTime) external override {
        if (acCode & AUTH_CODE_MIRROR != 0) {
            grantRole(ROLE_MIRROR, account, expireTime);
        } else if (acCode & AUTH_CODE_CREATE != 0) {
            grantRole(ROLE_CREATE, account, expireTime);
        } else if (acCode & AUTH_CODE_DELETE != 0) {
            grantRole(ROLE_DELETE, account, expireTime);
        } else if (acCode & AUTH_CODE_UPDATE != 0) {
            grantRole(ROLE_UPDATE, account, expireTime);
        } else {
            revert("unknown authorization code");
        }
    }

    function revoke(address account, uint32 acCode) external override {
        if (acCode & AUTH_CODE_MIRROR != 0) {
            revokeRole(ROLE_MIRROR, account);
        } else if (acCode & AUTH_CODE_CREATE != 0) {
            revokeRole(ROLE_CREATE, account);
        } else if (acCode & AUTH_CODE_DELETE != 0) {
            revokeRole(ROLE_DELETE, account);
        } else if (acCode & AUTH_CODE_UPDATE != 0) {
            revokeRole(ROLE_UPDATE, account);
        } else {
            revert("unknown authorization code");
        }
    }

    /*----------------- update param -----------------*/
    function updateParam(string calldata key, bytes calldata value) external override onlyGovHub {
        if (Memory.compareStrings(key, "ERC721BaseURI")) {
            IERC721NonTransferable(ERC721Token).setBaseURI(string(value));
        } else if (Memory.compareStrings(key, "ERC1155BaseURI")) {
            IERC1155NonTransferable(ERC1155Token).setBaseURI(string(value));
        } else {
            revert("unknown param");
        }
        emit ParamChange(key, value);
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

    function _doCreate(address creator, uint256 id) internal override {
        IERC721NonTransferable(ERC721Token).mint(creator, id);
        string memory tokenURI = IERC721NonTransferable(ERC721Token).tokenURI(id);
        IERC1155NonTransferable(ERC1155Token).setTokenURI(id, tokenURI);
        emit CreateSuccess(creator, id);
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

    function _decodeUpdateAckPackage(RLPDecode.Iterator memory iter)
        internal
        pure
        returns (UpdateAckPackage memory, bool)
    {
        UpdateAckPackage memory ackPkg;

        bool success = false;
        uint256 idx = 0;
        while (iter.hasNext()) {
            if (idx == 0) {
                ackPkg.status = uint32(iter.next().toUint());
            } else if (idx == 1) {
                ackPkg.operator = iter.next().toAddress();
            } else if (idx == 2) {
                ackPkg.id = iter.next().toUint();
            } else if (idx == 3) {
                ackPkg.opType = uint8(iter.next().toUint());
            } else if (idx == 4) {
                RLPDecode.RLPItem[] memory memsIter = iter.next().toList();
                address[] memory mems = new address[](memsIter.length);
                for (uint256 i; i < memsIter.length; ++i) {
                    mems[i] = memsIter[i].toAddress();
                }
                ackPkg.members = mems;
                success = true;
            } else {
                break;
            }
            idx++;
        }
        return (ackPkg, success);
    }

    function _handleUpdateAckPackage(RLPDecode.Iterator memory iter) internal {
        (UpdateAckPackage memory ackPkg, bool success) = _decodeUpdateAckPackage(iter);
        require(success, "unrecognized update ack package");

        if (ackPkg.status == STATUS_SUCCESS) {
            _doUpdate(ackPkg);
        } else if (ackPkg.status == STATUS_FAILED) {
            emit UpdateFailed(ackPkg.operator, ackPkg.id, ackPkg.opType);
        } else {
            revert("unexpected status code");
        }
    }

    function _doUpdate(UpdateAckPackage memory ackPkg) internal {
        if (ackPkg.opType == UPDATE_ADD) {
            for (uint256 i; i < ackPkg.members.length; ++i) {
                IERC1155NonTransferable(ERC1155Token).mint(ackPkg.members[i], ackPkg.id, 1, "");
            }
        } else if (ackPkg.opType == UPDATE_DELETE) {
            for (uint256 i; i < ackPkg.members.length; ++i) {
                IERC1155NonTransferable(ERC1155Token).burn(ackPkg.members[i], ackPkg.id, 1);
            }
        } else {
            revert("unexpected update operation");
        }
        emit UpdateSuccess(ackPkg.operator, ackPkg.id, ackPkg.opType);
    }
}
