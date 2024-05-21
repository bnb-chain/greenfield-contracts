// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/DoubleEndedQueueUpgradeable.sol";

import "./storage/GroupStorage.sol";
import "./utils/GnfdAccessControl.sol";
import "../../interface/IApplication.sol";
import "../../interface/ICrossChain.sol";
import "../../interface/IERC721NonTransferable.sol";
import "../../interface/IERC1155NonTransferable.sol";

// Highlight: This contract must have the same storage layout as GroupHub
// which means same state variables and same order of state variables.
// Because it will be used as a delegate call target.
// NOTE: The inherited contracts order must be the same as GroupHub.
contract AdditionalGroupHub is GroupStorage, GnfdAccessControl {
    // PlaceHolder corresponding to `Initializable` contract
    uint8 private _initialized;
    bool private _initializing;

    using DoubleEndedQueueUpgradeable for DoubleEndedQueueUpgradeable.Bytes32Deque;

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
        (uint8 _channelId, bytes memory _msgBytes, uint256 _relayFee, uint256 _ackRelayFee, ) = _prepareCreateGroup(
            _erc2771Sender(),
            owner,
            name
        );

        ICrossChain(CROSS_CHAIN).sendSynPackage(_channelId, _msgBytes, _relayFee, _ackRelayFee);
        return true;
    }

    function prepareCreateGroup(
        address sender,
        address owner,
        string memory name
    ) external payable onlyMultiMessage returns (uint8, bytes memory, uint256, uint256, address) {
        return _prepareCreateGroup(sender, owner, name);
    }

    /**
     * @dev create a group and send cross-chain request from BSC to GNFD.
     * Callback function will be called when the request is processed.
     *
     * @param owner The group's owner
     * @param name The group's name
     * @param callbackGasLimit The gas limit for callback function
     * @param extraData Extra data for callback function. The `appAddress` in `extraData` will be ignored.
     * It will be reset to the `msg.sender` all the time. And make sure the `refundAddress` is payable.
     */
    function createGroup(
        address owner,
        string memory name,
        uint256 callbackGasLimit,
        ExtraData memory extraData
    ) external payable returns (bool) {
        (uint8 _channelId, bytes memory _msgBytes, uint256 _relayFee, uint256 _ackRelayFee, ) = _prepareCreateGroup(
            _erc2771Sender(),
            owner,
            name,
            callbackGasLimit,
            extraData
        );

        ICrossChain(CROSS_CHAIN).sendSynPackage(_channelId, _msgBytes, _relayFee, _ackRelayFee);
        return true;
    }

    function prepareCreateGroup(
        address sender,
        address owner,
        string memory name,
        uint256 callbackGasLimit,
        ExtraData memory extraData
    ) external payable onlyMultiMessage returns (uint8, bytes memory, uint256, uint256, address) {
        return _prepareCreateGroup(sender, owner, name, callbackGasLimit, extraData);
    }

    /**
     * @dev delete a group and send cross-chain request from BSC to GNFD
     *
     * @param id The group's id
     */
    function deleteGroup(uint256 id) external payable returns (bool) {
        (uint8 _channelId, bytes memory _msgBytes, uint256 _relayFee, uint256 _ackRelayFee, ) = _prepareDeleteGroup(
            _erc2771Sender(),
            id
        );
        ICrossChain(CROSS_CHAIN).sendSynPackage(_channelId, _msgBytes, _relayFee, _ackRelayFee);
        return true;
    }

    function prepareDeleteGroup(
        address sender,
        uint256 id
    ) external payable onlyMultiMessage returns (uint8, bytes memory, uint256, uint256, address) {
        return _prepareDeleteGroup(sender, id);
    }

    /**
     * @dev delete a group and send cross-chain request from BSC to GNFD
     * Callback function will be called when the request is processed.
     *
     * @param id The group's id
     * @param callbackGasLimit The gas limit for callback function
     * @param extraData Extra data for callback function. The `appAddress` in `extraData` will be ignored.
     * It will be reset to the `msg.sender` all the time. And make sure the `refundAddress` is payable.
     */
    function deleteGroup(
        uint256 id,
        uint256 callbackGasLimit,
        ExtraData memory extraData
    ) external payable returns (bool) {
        (uint8 _channelId, bytes memory _msgBytes, uint256 _relayFee, uint256 _ackRelayFee, ) = _prepareDeleteGroup(
            _erc2771Sender(),
            id,
            callbackGasLimit,
            extraData
        );
        ICrossChain(CROSS_CHAIN).sendSynPackage(_channelId, _msgBytes, _relayFee, _ackRelayFee);
        return true;
    }

    function prepareDeleteGroup(
        address sender,
        uint256 id,
        uint256 callbackGasLimit,
        ExtraData memory extraData
    ) external payable onlyMultiMessage returns (uint8, bytes memory, uint256, uint256, address) {
        return _prepareDeleteGroup(sender, id, callbackGasLimit, extraData);
    }

    /**
     * @dev update a group's member and send cross-chain request from BSC to GNFD
     *
     * @param synPkg Package containing information of the group to be updated
     */
    function updateGroup(UpdateGroupSynPackage memory synPkg) external payable returns (bool) {
        (uint8 _channelId, bytes memory _msgBytes, uint256 _relayFee, uint256 _ackRelayFee, ) = _prepareUpdateGroup(
            _erc2771Sender(),
            synPkg
        );

        ICrossChain(CROSS_CHAIN).sendSynPackage(_channelId, _msgBytes, _relayFee, _ackRelayFee);
        return true;
    }

    function prepareUpdateGroup(
        address sender,
        UpdateGroupSynPackage memory synPkg
    ) external payable onlyMultiMessage returns (uint8, bytes memory, uint256, uint256, address) {
        return _prepareUpdateGroup(sender, synPkg);
    }

    /**
     * @dev update a group's member and send cross-chain request from BSC to GNFD
     * Callback function will be called when the request is processed.
     *
     * @param synPkg Package containing information of the group to be updated
     * @param callbackGasLimit The gas limit for callback function
     * @param extraData Extra data for callback function. The `appAddress` in `extraData` will be ignored.
     * It will be reset to the `msg.sender` all the time. And make sure the `refundAddress` is payable.
     */
    function updateGroup(
        UpdateGroupSynPackage memory synPkg,
        uint256 callbackGasLimit,
        ExtraData memory extraData
    ) external payable returns (bool) {
        (uint8 _channelId, bytes memory _msgBytes, uint256 _relayFee, uint256 _ackRelayFee, ) = _prepareUpdateGroup(
            _erc2771Sender(),
            synPkg,
            callbackGasLimit,
            extraData
        );

        ICrossChain(CROSS_CHAIN).sendSynPackage(_channelId, _msgBytes, _relayFee, _ackRelayFee);
        return true;
    }

    function prepareUpdateGroup(
        address sender,
        UpdateGroupSynPackage memory synPkg,
        uint256 callbackGasLimit,
        ExtraData memory extraData
    ) external payable onlyMultiMessage returns (uint8, bytes memory, uint256, uint256, address) {
        return _prepareUpdateGroup(sender, synPkg, callbackGasLimit, extraData);
    }

    function _prepareCreateGroup(
        address sender,
        address owner,
        string memory name
    ) internal returns (uint8, bytes memory, uint256, uint256, address) {
        // check relay fee
        (uint256 relayFee, uint256 minAckRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        require(msg.value >= relayFee + minAckRelayFee, "not enough fee");
        uint256 _ackRelayFee = msg.value - relayFee;

        {
            address _sender = sender;
            // check authorization
            if (_sender != owner) {
                require(hasRole(ROLE_CREATE, owner, _sender), "no permission to create");
            }

            // transfer all the fee to tokenHub
            (bool success, ) = TOKEN_HUB.call{ value: address(this).balance }("");
            require(success, "transfer to tokenHub failed");

            CreateGroupSynPackage memory synPkg = CreateGroupSynPackage({ creator: owner, name: name, extraData: "" });
            emit CreateSubmitted(owner, _sender, synPkg.name);

            return (
                GROUP_CHANNEL_ID,
                abi.encodePacked(TYPE_CREATE, abi.encode(synPkg)),
                relayFee,
                _ackRelayFee,
                _sender
            );
        }
    }

    function _prepareCreateGroup(
        address sender,
        address owner,
        string memory name,
        uint256 callbackGasLimit,
        ExtraData memory extraData
    ) internal returns (uint8, bytes memory, uint256, uint256, address) {
        // check relay fee and callback fee
        require(callbackGasLimit > 2300, "invalid callback gas limit");
        require(callbackGasLimit <= MAX_CALLBACK_GAS_LIMIT, "invalid callback gas limit");
        (uint256 relayFee, uint256 minAckRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        uint256 callbackGasPrice = ICrossChain(CROSS_CHAIN).callbackGasPrice();
        require(msg.value >= relayFee + minAckRelayFee + callbackGasLimit * callbackGasPrice, "not enough fee");
        uint256 _ackRelayFee = msg.value - relayFee;

        {
            address _sender = sender;
            address _owner = owner;
            string memory _name = name;
            // check package queue
            if (extraData.failureHandleStrategy == FailureHandleStrategy.BlockOnFail) {
                require(retryQueue[_sender].empty(), "retry queue is not empty");
            }

            // check authorization
            if (_sender != _owner) {
                require(hasRole(ROLE_CREATE, _owner, _sender), "no permission to create");
            }

            // make sure the extra data is as expected
            require(extraData.callbackData.length < maxCallbackDataLength, "callback data too long");
            extraData.appAddress = _sender;

            CreateGroupSynPackage memory synPkg = CreateGroupSynPackage({
                creator: _owner,
                name: _name,
                extraData: abi.encode(extraData)
            });

            emit CreateSubmitted(_owner, _sender, _name);

            // transfer all the fee to tokenHub
            (bool success, ) = TOKEN_HUB.call{ value: address(this).balance }("");
            require(success, "transfer to tokenHub failed");

            return (
                GROUP_CHANNEL_ID,
                abi.encodePacked(TYPE_CREATE, abi.encode(synPkg)),
                relayFee,
                _ackRelayFee,
                _sender
            );
        }
    }

    function _prepareDeleteGroup(
        address sender,
        uint256 id
    ) internal returns (uint8, bytes memory, uint256, uint256, address) {
        // check relay fee
        (uint256 relayFee, uint256 minAckRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        require(msg.value >= relayFee + minAckRelayFee, "not enough fee");
        uint256 _ackRelayFee = msg.value - relayFee;

        address _sender = sender;
        // check authorization
        address owner = IERC721NonTransferable(ERC721Token).ownerOf(id);
        if (
            !(_sender == owner ||
                IERC721NonTransferable(ERC721Token).getApproved(id) == _sender ||
                IERC721NonTransferable(ERC721Token).isApprovedForAll(owner, _sender))
        ) {
            require(hasRole(ROLE_DELETE, owner, _sender), "no delete permission");
        }

        // make sure the extra data is as expected
        CmnDeleteSynPackage memory synPkg = CmnDeleteSynPackage({ operator: owner, id: id, extraData: "" });

        // transfer all the fee to tokenHub
        (bool success, ) = TOKEN_HUB.call{ value: address(this).balance }("");
        require(success, "transfer to tokenHub failed");

        emit DeleteSubmitted(owner, _sender, id);

        return (GROUP_CHANNEL_ID, abi.encodePacked(TYPE_DELETE, abi.encode(synPkg)), relayFee, _ackRelayFee, _sender);
    }

    function _prepareDeleteGroup(
        address sender,
        uint256 id,
        uint256 callbackGasLimit,
        ExtraData memory extraData
    ) internal returns (uint8, bytes memory, uint256, uint256, address) {
        // check relay fee and callback fee
        require(callbackGasLimit > 2300, "invalid callback gas limit");
        require(callbackGasLimit <= MAX_CALLBACK_GAS_LIMIT, "invalid callback gas limit");
        (uint256 relayFee, uint256 minAckRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        uint256 callbackGasPrice = ICrossChain(CROSS_CHAIN).callbackGasPrice();
        require(msg.value >= relayFee + minAckRelayFee + callbackGasLimit * callbackGasPrice, "not enough fee");
        uint256 _ackRelayFee = msg.value - relayFee;

        uint256 _id = id;
        address _sender = sender;
        // check package queue
        if (extraData.failureHandleStrategy == FailureHandleStrategy.BlockOnFail) {
            require(retryQueue[_sender].empty(), "retry queue is not empty");
        }

        // check authorization
        require(extraData.callbackData.length < maxCallbackDataLength, "callback data too long");
        address owner = IERC721NonTransferable(ERC721Token).ownerOf(_id);
        if (
            !(_sender == owner ||
                IERC721NonTransferable(ERC721Token).getApproved(_id) == _sender ||
                IERC721NonTransferable(ERC721Token).isApprovedForAll(owner, _sender))
        ) {
            require(hasRole(ROLE_DELETE, owner, _sender), "no delete permission");
        }

        // make sure the extra data is as expected
        extraData.appAddress = _sender;
        CmnDeleteSynPackage memory synPkg = CmnDeleteSynPackage({
            operator: owner,
            id: _id,
            extraData: abi.encode(extraData)
        });

        // transfer all the fee to tokenHub
        (bool success, ) = TOKEN_HUB.call{ value: address(this).balance }("");
        require(success, "transfer to tokenHub failed");

        emit DeleteSubmitted(owner, _sender, _id);
        return (GROUP_CHANNEL_ID, abi.encodePacked(TYPE_DELETE, abi.encode(synPkg)), relayFee, _ackRelayFee, _sender);
    }

    function _prepareUpdateGroup(
        address sender,
        UpdateGroupSynPackage memory synPkg
    ) internal returns (uint8, bytes memory, uint256, uint256, address) {
        // check synPkg
        if (synPkg.opType == UpdateGroupOpType.AddMembers || synPkg.opType == UpdateGroupOpType.RenewMembers) {
            require(synPkg.members.length == synPkg.memberExpiration.length, "member and expiration length mismatch");
        }

        // check relay fee
        (uint256 relayFee, uint256 minAckRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        require(msg.value >= relayFee + minAckRelayFee, "not enough fee");
        uint256 _ackRelayFee = msg.value - relayFee;

        // check authorization
        address owner = IERC721NonTransferable(ERC721Token).ownerOf(synPkg.id);
        if (
            !(sender == owner ||
                IERC721NonTransferable(ERC721Token).getApproved(synPkg.id) == sender ||
                IERC721NonTransferable(ERC721Token).isApprovedForAll(owner, sender))
        ) {
            require(hasRole(ROLE_UPDATE, owner, sender), "no update permission");
        }
        synPkg.operator = owner; // the operator should always be set to the owner

        // check members
        if (synPkg.opType == UpdateGroupOpType.AddMembers) {
            for (uint256 i = 0; i < synPkg.members.length; ++i) {
                require(synPkg.members[i] != address(0), "invalid member address");
                require(
                    IERC1155NonTransferable(ERC1155Token).balanceOf(synPkg.members[i], synPkg.id) == 0,
                    "member already in group"
                );
            }
        } else {
            for (uint256 i = 0; i < synPkg.members.length; ++i) {
                require(synPkg.members[i] != address(0), "invalid member address");
                require(
                    IERC1155NonTransferable(ERC1155Token).balanceOf(synPkg.members[i], synPkg.id) != 0,
                    "member not in group"
                );
            }
        }

        // make sure the extra data is as expected
        synPkg.extraData = "";

        // transfer all the fee to tokenHub
        (bool success, ) = TOKEN_HUB.call{ value: address(this).balance }("");
        require(success, "transfer to tokenHub failed");

        emit UpdateSubmitted(owner, sender, synPkg.id, uint8(synPkg.opType), synPkg.members);
        return (GROUP_CHANNEL_ID, abi.encodePacked(TYPE_UPDATE, abi.encode(synPkg)), relayFee, _ackRelayFee, sender);
    }

    function _prepareUpdateGroup(
        address sender,
        UpdateGroupSynPackage memory synPkg,
        uint256 callbackGasLimit,
        ExtraData memory extraData
    ) internal returns (uint8, bytes memory, uint256, uint256, address) {
        // check synPkg
        if (synPkg.opType == UpdateGroupOpType.AddMembers || synPkg.opType == UpdateGroupOpType.RenewMembers) {
            require(synPkg.members.length == synPkg.memberExpiration.length, "member and expiration length mismatch");
        }

        // check relay fee and callback fee
        require(callbackGasLimit > 2300, "invalid callback gas limit");
        require(callbackGasLimit <= MAX_CALLBACK_GAS_LIMIT, "invalid callback gas limit");
        (uint256 relayFee, uint256 minAckRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        uint256 callbackGasPrice = ICrossChain(CROSS_CHAIN).callbackGasPrice();
        require(msg.value >= relayFee + minAckRelayFee + callbackGasLimit * callbackGasPrice, "not enough fee");
        uint256 _ackRelayFee = msg.value - relayFee;

        address _sender = sender;

        // check package queue
        if (extraData.failureHandleStrategy == FailureHandleStrategy.BlockOnFail) {
            require(retryQueue[_sender].empty(), "retry queue is not empty");
        }

        // check authorization
        uint256 id = synPkg.id;
        address owner = IERC721NonTransferable(ERC721Token).ownerOf(id);
        if (
            !(_sender == owner ||
                IERC721NonTransferable(ERC721Token).getApproved(id) == _sender ||
                IERC721NonTransferable(ERC721Token).isApprovedForAll(owner, _sender))
        ) {
            require(hasRole(ROLE_UPDATE, owner, _sender), "no update permission");
        }
        synPkg.operator = owner; // the operator should always be set to the owner

        // check members
        UpdateGroupSynPackage memory _synPkg = synPkg;

        if (_synPkg.opType == UpdateGroupOpType.AddMembers) {
            for (uint256 i = 0; i < _synPkg.members.length; ++i) {
                require(_synPkg.members[i] != address(0), "invalid member address");
                require(
                    IERC1155NonTransferable(ERC1155Token).balanceOf(_synPkg.members[i], _synPkg.id) == 0,
                    "member already in group"
                );
            }
        } else {
            for (uint256 i = 0; i < _synPkg.members.length; ++i) {
                require(_synPkg.members[i] != address(0), "invalid member address");
                require(
                    IERC1155NonTransferable(ERC1155Token).balanceOf(_synPkg.members[i], _synPkg.id) != 0,
                    "member not in group"
                );
            }
        }

        // make sure the extra data is as expected
        require(extraData.callbackData.length < maxCallbackDataLength, "callback data too long");
        extraData.appAddress = _sender;
        _synPkg.extraData = abi.encode(extraData);

        // transfer all the fee to tokenHub
        (bool success, ) = TOKEN_HUB.call{ value: address(this).balance }("");
        require(success, "transfer to tokenHub failed");

        emit UpdateSubmitted(owner, _sender, id, uint8(_synPkg.opType), _synPkg.members);
        return (GROUP_CHANNEL_ID, abi.encodePacked(TYPE_UPDATE, abi.encode(_synPkg)), relayFee, _ackRelayFee, _sender);
    }
}
