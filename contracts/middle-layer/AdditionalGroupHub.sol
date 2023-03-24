// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/DoubleEndedQueueUpgradeable.sol";

import "./AccessControl.sol";
import "./NFTWrapResourceStorage.sol";
import "../interface/IApplication.sol";
import "../interface/ICrossChain.sol";
import "../interface/IERC721NonTransferable.sol";
import "../lib/RLPDecode.sol";
import "../lib/RLPEncode.sol";

// Highlight: This contract must have the same storage layout as GroupHub
// which means same state variables and same order of state variables.
// Because it will be used as a delegate call target.
// NOTE: The inherited contracts order must be the same as GroupHub.
contract AdditionalGroupHub is NFTWrapResourceStorage, Initializable, AccessControl {
    using DoubleEndedQueueUpgradeable for DoubleEndedQueueUpgradeable.Bytes32Deque;
    using RLPEncode for *;
    using RLPDecode for *;

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

    // ERC1155 token contract
    address public ERC1155Token;

    /*----------------- external function -----------------*/

    /**
     * @dev grant some authorization to an account
     *
     * @param account The address of the account to be granted
     * @param acCode The authorization code
     * @param expireTime The expiration time of the authorization
     */
    function grant(address account, uint32 acCode, uint256 expireTime) external {
        if (expireTime == 0) {
            expireTime = block.timestamp + 30 days; // 30 days in default
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

    /**
     * @dev revoke some authorization from an account
     *
     * @param account The address of the account to be revoked
     * @param acCode The authorization code
     */
    function revoke(address account, uint32 acCode) external {
        if (acCode & AUTH_CODE_CREATE != 0) {
            acCode = acCode & ~AUTH_CODE_CREATE;
            revokeRole(ROLE_CREATE, account);
        }
        if (acCode & AUTH_CODE_DELETE != 0) {
            acCode = acCode & ~AUTH_CODE_DELETE;
            revokeRole(ROLE_DELETE, account);
        }
        if (acCode & AUTH_CODE_UPDATE != 0) {
            acCode = acCode & ~AUTH_CODE_UPDATE;
            revokeRole(ROLE_UPDATE, account);
        }

        require(acCode == 0, "invalid authorization code");
    }

    /**
     * @dev create a group and send cross-chain request from BSC to GNFD
     *
     * @param owner The group's owner
     * @param name The group's name
     */
    function createGroup(address owner, string memory name) external payable returns (bool) {
        // check relay fee
        (uint256 relayFee, uint256 minAckRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        require(msg.value >= relayFee + minAckRelayFee, "not enough fee");
        uint256 _ackRelayFee = msg.value - relayFee;

        // check authorization
        if (msg.sender != owner) {
            require(hasRole(ROLE_CREATE, owner, msg.sender), "no permission to create");
        }

        // make sure the extra data is as expected
        CreateGroupSynPackage memory synPkg = CreateGroupSynPackage({ creator: owner, name: name, extraData: "" });

        ICrossChain(CROSS_CHAIN).sendSynPackage(
            GROUP_CHANNEL_ID,
            _encodeCreateGroupSynPackage(synPkg),
            relayFee,
            _ackRelayFee
        );
        emit CreateSubmitted(owner, msg.sender, name);
        return true;
    }

    /**
     * @dev create a group and send cross-chain request from BSC to GNFD.
     * Callback function will be called when the request is processed.
     *
     * @param owner The group's owner
     * @param name The group's name
     * @param callbackGasLimit The gas limit for callback function
     * @param extraData Extra data for callback function. The `appAddress` in `extraData` will be ignored.
     * It will be reset as the `msg.sender` all the time.
     */
    function createGroup(
        address owner,
        string memory name,
        uint256 callbackGasLimit,
        ExtraData memory extraData
    ) external payable returns (bool) {
        // check relay fee and callback fee
        (uint256 relayFee, uint256 minAckRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        uint256 callbackGasPrice = ICrossChain(CROSS_CHAIN).callbackGasPrice();
        require(msg.value >= relayFee + minAckRelayFee + callbackGasLimit * callbackGasPrice, "not enough fee");
        uint256 _ackRelayFee = msg.value - relayFee;

        // check package queue
        if (extraData.failureHandleStrategy == FailureHandleStrategy.BlockOnFail) {
            require(retryQueue[msg.sender].length() == 0, "retry queue is not empty");
        }

        // check authorization
        if (msg.sender != owner) {
            require(hasRole(ROLE_CREATE, owner, msg.sender), "no permission to create");
        }

        // make sure the extra data is as expected
        extraData.appAddress = msg.sender;
        CreateGroupSynPackage memory synPkg = CreateGroupSynPackage({
            creator: owner,
            name: name,
            extraData: _extraDataToBytes(extraData)
        });

        // check refund address
        (bool success, ) = extraData.refundAddress.call("");
        require(success && (extraData.refundAddress != address(0)), "invalid refund address");

        ICrossChain(CROSS_CHAIN).sendSynPackage(
            GROUP_CHANNEL_ID,
            _encodeCreateGroupSynPackage(synPkg),
            relayFee,
            _ackRelayFee
        );
        emit CreateSubmitted(owner, msg.sender, name);
        return true;
    }

    /**
     * @dev delete a group and send cross-chain request from BSC to GNFD
     *
     * @param id The group's id
     */
    function deleteGroup(uint256 id) external payable returns (bool) {
        // check relay fee
        (uint256 relayFee, uint256 minAckRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        require(msg.value >= relayFee + minAckRelayFee, "not enough fee");
        uint256 _ackRelayFee = msg.value - relayFee;

        // check authorization
        address owner = IERC721NonTransferable(ERC721Token).ownerOf(id);
        if (
            !(msg.sender == owner ||
                IERC721NonTransferable(ERC721Token).getApproved(id) == msg.sender ||
                IERC721NonTransferable(ERC721Token).isApprovedForAll(owner, msg.sender))
        ) {
            require(hasRole(ROLE_DELETE, owner, msg.sender), "no delete permission");
        }

        // make sure the extra data is as expected
        CmnDeleteSynPackage memory synPkg = CmnDeleteSynPackage({ operator: owner, id: id, extraData: "" });

        ICrossChain(CROSS_CHAIN).sendSynPackage(
            GROUP_CHANNEL_ID,
            _encodeCmnDeleteSynPackage(synPkg),
            relayFee,
            _ackRelayFee
        );
        emit DeleteSubmitted(owner, msg.sender, id);
        return true;
    }

    /**
     * @dev delete a group and send cross-chain request from BSC to GNFD
     * Callback function will be called when the request is processed.
     *
     * @param id The group's id
     * @param callbackGasLimit The gas limit for callback function
     * @param extraData Extra data for callback function. The `appAddress` in `extraData` will be ignored.
     * It will be reset as the `msg.sender` all the time.
     */
    function deleteGroup(
        uint256 id,
        uint256 callbackGasLimit,
        ExtraData memory extraData
    ) external payable returns (bool) {
        // check relay fee and callback fee
        (uint256 relayFee, uint256 minAckRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        uint256 callbackGasPrice = ICrossChain(CROSS_CHAIN).callbackGasPrice();
        require(msg.value >= relayFee + minAckRelayFee + callbackGasLimit * callbackGasPrice, "not enough fee");
        uint256 _ackRelayFee = msg.value - relayFee;

        // check package queue
        if (extraData.failureHandleStrategy == FailureHandleStrategy.BlockOnFail) {
            require(retryQueue[msg.sender].length() == 0, "retry queue is not empty");
        }

        // check authorization
        address owner = IERC721NonTransferable(ERC721Token).ownerOf(id);
        if (
            !(msg.sender == owner ||
                IERC721NonTransferable(ERC721Token).getApproved(id) == msg.sender ||
                IERC721NonTransferable(ERC721Token).isApprovedForAll(owner, msg.sender))
        ) {
            require(hasRole(ROLE_DELETE, owner, msg.sender), "no delete permission");
        }

        // make sure the extra data is as expected
        extraData.appAddress = msg.sender;
        CmnDeleteSynPackage memory synPkg = CmnDeleteSynPackage({
            operator: owner,
            id: id,
            extraData: _extraDataToBytes(extraData)
        });

        // check refund address
        (bool success, ) = extraData.refundAddress.call("");
        require(success && (extraData.refundAddress != address(0)), "invalid refund address"); // the refund address must be payable

        ICrossChain(CROSS_CHAIN).sendSynPackage(
            GROUP_CHANNEL_ID,
            _encodeCmnDeleteSynPackage(synPkg),
            relayFee,
            _ackRelayFee
        );
        emit DeleteSubmitted(owner, msg.sender, id);
        return true;
    }

    /**
     * @dev update a group's member and send cross-chain request from BSC to GNFD
     *
     * @param synPkg Package containing information of the group to be updated
     */
    function updateGroup(UpdateGroupSynPackage memory synPkg) external payable returns (bool) {
        // check relay fee
        (uint256 relayFee, uint256 minAckRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        require(msg.value >= relayFee + minAckRelayFee, "not enough fee");
        uint256 _ackRelayFee = msg.value - relayFee;

        // check authorization
        address owner = IERC721NonTransferable(ERC721Token).ownerOf(synPkg.id);
        if (
            !(msg.sender == owner ||
                IERC721NonTransferable(ERC721Token).getApproved(synPkg.id) == msg.sender ||
                IERC721NonTransferable(ERC721Token).isApprovedForAll(owner, msg.sender))
        ) {
            require(hasRole(ROLE_UPDATE, owner, msg.sender), "no update permission");
        }

        // make sure the extra data is as expected
        synPkg.extraData = "";

        ICrossChain(CROSS_CHAIN).sendSynPackage(
            GROUP_CHANNEL_ID,
            _encodeUpdateGroupSynPackage(synPkg),
            relayFee,
            _ackRelayFee
        );
        emit UpdateSubmitted(owner, msg.sender, synPkg.id, synPkg.opType, synPkg.members);
        return true;
    }

    /**
     * @dev update a group's member and send cross-chain request from BSC to GNFD
     * Callback function will be called when the request is processed.
     *
     * @param synPkg Package containing information of the group to be updated
     * @param callbackGasLimit The gas limit for callback function
     * @param extraData Extra data for callback function. The `appAddress` in `extraData` will be ignored.
     * It will be reset as the `msg.sender` all the time.
     */
    function updateGroup(
        UpdateGroupSynPackage memory synPkg,
        uint256 callbackGasLimit,
        ExtraData memory extraData
    ) external payable returns (bool) {
        // check relay fee and callback fee
        (uint256 relayFee, uint256 minAckRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        uint256 callbackGasPrice = ICrossChain(CROSS_CHAIN).callbackGasPrice();
        require(msg.value >= relayFee + minAckRelayFee + callbackGasLimit * callbackGasPrice, "not enough fee");
        uint256 _ackRelayFee = msg.value - relayFee;

        // check package queue
        if (extraData.failureHandleStrategy == FailureHandleStrategy.BlockOnFail) {
            require(retryQueue[msg.sender].length() == 0, "retry queue is not empty");
        }

        // check authorization
        address owner = IERC721NonTransferable(ERC721Token).ownerOf(synPkg.id);
        if (
            !(msg.sender == owner ||
                IERC721NonTransferable(ERC721Token).getApproved(synPkg.id) == msg.sender ||
                IERC721NonTransferable(ERC721Token).isApprovedForAll(owner, msg.sender))
        ) {
            require(hasRole(ROLE_UPDATE, owner, msg.sender), "no update permission");
        }

        // make sure the extra data is as expected
        extraData.appAddress = msg.sender;
        synPkg.extraData = _extraDataToBytes(extraData);

        // check refund address
        (bool success, ) = extraData.refundAddress.call("");
        require(success && (extraData.refundAddress != address(0)), "invalid refund address"); // the refund address must be payable

        ICrossChain(CROSS_CHAIN).sendSynPackage(
            GROUP_CHANNEL_ID,
            _encodeUpdateGroupSynPackage(synPkg),
            relayFee,
            _ackRelayFee
        );
        emit UpdateSubmitted(owner, msg.sender, synPkg.id, synPkg.opType, synPkg.members);
        return true;
    }

    function retryPackage() external {
        CallbackPackage memory callbackPkg = getRetryPackage(msg.sender);
        if (callbackPkg.isFailAck) {
            if (callbackPkg.pkgType == CREATE_GROUP_SYN) {
                (CreateGroupSynPackage memory synPkg, bool success) = _decodeCreateGroupSynPackage(
                    callbackPkg.msgBytes
                );
                require(success, "decode create group fail ack package failed");

                IApplication(callbackPkg.appAddress).handleFailAckPackage(channelId, synPkg, callbackPkg.callbackData);

                bytes32 pkgHash = retryQueue[callbackPkg.appAddress].popFront();
                delete packageMap[pkgHash];
            } else if (callbackPkg.pkgType == CMN_DELETE_SYN) {
                (CmnDeleteSynPackage memory synPkg, bool success) = _decodeCmnDeleteSynPackage(callbackPkg.msgBytes);
                require(success, "decode delete group fail ack package failed");

                IApplication(callbackPkg.appAddress).handleFailAckPackage(channelId, synPkg, callbackPkg.callbackData);

                bytes32 pkgHash = retryQueue[callbackPkg.appAddress].popFront();
                delete packageMap[pkgHash];
            } else if (callbackPkg.pkgType == UPDATE_GROUP_SYN) {
                (UpdateGroupSynPackage memory synPkg, bool success) = _decodeUpdateGroupSynPackage(
                    callbackPkg.msgBytes
                );
                require(success, "decode update group fail ack package failed");

                IApplication(callbackPkg.appAddress).handleFailAckPackage(channelId, synPkg, callbackPkg.callbackData);

                bytes32 pkgHash = retryQueue[callbackPkg.appAddress].popFront();
                delete packageMap[pkgHash];
            } else {
                revert("invalid callback package type");
            }
        } else {
            if (callbackPkg.pkgType == CMN_CREATE_ACK) {
                (CmnCreateAckPackage memory ackPkg, bool success) = _decodeCmnCreateAckPackage(callbackPkg.msgBytes);
                require(success, "decode create group ack package failed");

                IApplication(callbackPkg.appAddress).handleAckPackage(channelId, ackPkg, callbackPkg.callbackData);

                bytes32 pkgHash = retryQueue[callbackPkg.appAddress].popFront();
                delete packageMap[pkgHash];
            } else if (callbackPkg.pkgType == CMN_DELETE_ACK) {
                (CmnDeleteAckPackage memory ackPkg, bool success) = _decodeCmnDeleteAckPackage(callbackPkg.msgBytes);
                require(success, "decode delete group ack package failed");

                IApplication(callbackPkg.appAddress).handleAckPackage(channelId, ackPkg, callbackPkg.callbackData);

                bytes32 pkgHash = retryQueue[callbackPkg.appAddress].popFront();
                delete packageMap[pkgHash];
            } else if (callbackPkg.pkgType == CMN_DELETE_ACK) {
                (UpdateGroupAckPackage memory ackPkg, bool success) = _decodeUpdateGroupAckPackage(
                    callbackPkg.msgBytes
                );
                require(success, "decode update group ack package failed");

                IApplication(callbackPkg.appAddress).handleAckPackage(channelId, ackPkg, callbackPkg.callbackData);

                bytes32 pkgHash = retryQueue[callbackPkg.appAddress].popFront();
                delete packageMap[pkgHash];
            } else {
                revert("invalid callback package type");
            }
        }
    }

    /*----------------- internal function -----------------*/
    function _encodeCreateGroupSynPackage(CreateGroupSynPackage memory synPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](3);
        elements[0] = synPkg.creator.encodeAddress();
        elements[1] = bytes(synPkg.name).encodeBytes();
        elements[2] = synPkg.extraData.encodeBytes();
        return _RLPEncode(TYPE_CREATE, elements.encodeList());
    }

    function _encodeCmnDeleteSynPackage(CmnDeleteSynPackage memory synPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](3);
        elements[0] = synPkg.operator.encodeAddress();
        elements[1] = synPkg.id.encodeUint();
        elements[2] = synPkg.extraData.encodeBytes();
        return _RLPEncode(TYPE_DELETE, elements.encodeList());
    }

    function _encodeUpdateGroupSynPackage(UpdateGroupSynPackage memory synPkg) internal pure returns (bytes memory) {
        bytes[] memory members = new bytes[](synPkg.members.length);
        for (uint256 i; i < synPkg.members.length; ++i) {
            members[i] = synPkg.members[i].encodeAddress();
        }

        bytes[] memory elements = new bytes[](5);
        elements[0] = synPkg.operator.encodeAddress();
        elements[1] = synPkg.id.encodeUint();
        elements[2] = uint256(synPkg.opType).encodeUint();
        elements[3] = members.encodeList();
        elements[4] = synPkg.extraData.encodeBytes();
        return _RLPEncode(TYPE_UPDATE, elements.encodeList());
    }

    function _decodeCreateGroupSynPackage(
        bytes memory pkgBytes
    ) internal pure returns (CreateGroupSynPackage memory synPkg, bool success) {
        RLPDecode.Iterator memory iter = pkgBytes.toRLPItem().iterator();

        uint256 idx;
        while (iter.hasNext()) {
            if (idx == 0) {
                synPkg.creator = iter.next().toAddress();
            } else if (idx == 1) {
                synPkg.name = string(iter.next().toBytes());
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

    function _decodeUpdateGroupSynPackage(
        bytes memory pkgBytes
    ) internal pure returns (UpdateGroupSynPackage memory synPkg, bool success) {
        RLPDecode.Iterator memory iter = pkgBytes.toRLPItem().iterator();

        uint256 idx;
        while (iter.hasNext()) {
            if (idx == 0) {
                synPkg.operator = iter.next().toAddress();
            } else if (idx == 1) {
                synPkg.id = iter.next().toUint();
            } else if (idx == 2) {
                synPkg.opType = uint8(iter.next().toUint());
            } else if (idx == 3) {
                RLPDecode.RLPItem[] memory membersIter = iter.next().toList();
                address[] memory members = new address[](membersIter.length);
                for (uint256 i; i < membersIter.length; ++i) {
                    members[i] = membersIter[i].toAddress();
                }
                synPkg.members = members;
            } else if (idx == 4) {
                synPkg.extraData = iter.next().toBytes();
                success = true;
            } else {
                break;
            }
            idx++;
        }
        return (synPkg, success);
    }

    function _decodeUpdateGroupAckPackage(
        bytes memory pkgBytes
    ) internal pure returns (UpdateGroupAckPackage memory, bool) {
        UpdateGroupAckPackage memory ackPkg;
        RLPDecode.Iterator memory iter = pkgBytes.toRLPItem().iterator();

        bool success;
        uint256 idx;
        while (iter.hasNext()) {
            if (idx == 0) {
                ackPkg.status = uint32(iter.next().toUint());
            } else if (idx == 1) {
                ackPkg.id = iter.next().toUint();
            } else if (idx == 2) {
                ackPkg.operator = iter.next().toAddress();
            } else if (idx == 3) {
                ackPkg.opType = uint8(iter.next().toUint());
            } else if (idx == 4) {
                RLPDecode.RLPItem[] memory membersIter = iter.next().toList();
                address[] memory members = new address[](membersIter.length);
                for (uint256 i; i < membersIter.length; ++i) {
                    members[i] = membersIter[i].toAddress();
                }
                ackPkg.members = members;
            } else if (idx == 5) {
                ackPkg.extraData = iter.next().toBytes();
                success = true;
            } else {
                break;
            }
            idx++;
        }
        return (ackPkg, success);
    }
}
