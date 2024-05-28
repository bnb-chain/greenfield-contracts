// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/DoubleEndedQueueUpgradeable.sol";

import "./storage/BucketStorage.sol";
import "./utils/GnfdAccessControl.sol";
import "../../interface/IApplication.sol";
import "../../interface/ICrossChain.sol";
import "../../interface/IERC721NonTransferable.sol";

// Highlight: This contract must have the same storage layout as BucketHub
// which means same state variables and same order of state variables.
// Because it will be used as a delegate call target.
// NOTE: The inherited contracts order must be the same as BucketHub.
contract AdditionalBucketHub is BucketStorage, GnfdAccessControl {
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

        require(acCode == 0, "invalid authorization code");
    }

    /**
     * @dev create a bucket and send cross-chain request from BSC to GNFD
     *
     * @param synPkg Package containing information of the bucket to be created
     */
    function createBucket(CreateBucketSynPackage memory synPkg) external payable returns (bool) {
        (uint8 _channelId, bytes memory _msgBytes, uint256 _relayFee, uint256 _ackRelayFee, ) = _prepareCreateBucket(
            _erc2771Sender(),
            synPkg
        );
        ICrossChain(CROSS_CHAIN).sendSynPackage(_channelId, _msgBytes, _relayFee, _ackRelayFee);
        return true;
    }

    function prepareCreateBucket(
        address sender,
        CreateBucketSynPackage memory synPkg
    ) external payable onlyMultiMessage returns (uint8, bytes memory, uint256, uint256, address) {
        return _prepareCreateBucket(sender, synPkg);
    }

    /**
     * @dev create a bucket and send cross-chain request from BSC to GNFD.
     * Callback function will be called when the request is processed.
     *
     * @param synPkg Package containing information of the bucket to be created
     * @param callbackGasLimit The gas limit for callback function
     * @param extraData Extra data for callback function. The `appAddress` in `extraData` will be ignored.
     * It will be reset to the `msg.sender` all the time. And make sure the `refundAddress` is payable.
     */
    function createBucket(
        CreateBucketSynPackage memory synPkg,
        uint256 callbackGasLimit,
        ExtraData memory extraData
    ) external payable returns (bool) {
        (uint8 _channelId, bytes memory _msgBytes, uint256 _relayFee, uint256 _ackRelayFee, ) = _prepareCreateBucket(
            _erc2771Sender(),
            synPkg,
            callbackGasLimit,
            extraData
        );

        ICrossChain(CROSS_CHAIN).sendSynPackage(_channelId, _msgBytes, _relayFee, _ackRelayFee);
        return true;
    }

    function prepareCreateBucket(
        address sender,
        CreateBucketSynPackage memory synPkg,
        uint256 callbackGasLimit,
        ExtraData memory extraData
    ) external payable onlyMultiMessage returns (uint8, bytes memory, uint256, uint256, address) {
        return _prepareCreateBucket(sender, synPkg, callbackGasLimit, extraData);
    }

    /**
     * @dev delete a bucket and send cross-chain request from BSC to GNFD
     *
     * @param id The bucket's id
     */
    function deleteBucket(uint256 id) external payable returns (bool) {
        (uint8 _channelId, bytes memory _msgBytes, uint256 _relayFee, uint256 _ackRelayFee, ) = _prepareDeleteBucket(
            _erc2771Sender(),
            id
        );

        ICrossChain(CROSS_CHAIN).sendSynPackage(_channelId, _msgBytes, _relayFee, _ackRelayFee);
        return true;
    }

    function prepareDeleteBucket(
        address sender,
        uint256 id
    ) external payable onlyMultiMessage returns (uint8, bytes memory, uint256, uint256, address) {
        return _prepareDeleteBucket(sender, id);
    }

    /**
     * @dev delete a bucket and send cross-chain request from BSC to GNFD.
     * Callback function will be called when the request is processed.
     *
     * @param id The bucket's id
     * @param callbackGasLimit The gas limit for callback function
     * @param extraData Extra data for callback function. The `appAddress` in `extraData` will be ignored.
     * It will be reset to the `msg.sender` all the time. And make sure the `refundAddress` is payable.
     */
    function deleteBucket(
        uint256 id,
        uint256 callbackGasLimit,
        ExtraData memory extraData
    ) external payable returns (bool) {
        (uint8 _channelId, bytes memory _msgBytes, uint256 _relayFee, uint256 _ackRelayFee, ) = _prepareDeleteBucket(
            _erc2771Sender(),
            id,
            callbackGasLimit,
            extraData
        );

        ICrossChain(CROSS_CHAIN).sendSynPackage(_channelId, _msgBytes, _relayFee, _ackRelayFee);
        return true;
    }

    function prepareDeleteBucket(
        address sender,
        uint256 id,
        uint256 callbackGasLimit,
        ExtraData memory extraData
    ) external payable onlyMultiMessage returns (uint8, bytes memory, uint256, uint256, address) {
        return _prepareDeleteBucket(sender, id, callbackGasLimit, extraData);
    }

    function _prepareCreateBucket(
        address sender,
        CreateBucketSynPackage memory synPkg
    ) internal returns (uint8, bytes memory, uint256, uint256, address) {
        // check relay fee
        (uint256 relayFee, uint256 minAckRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        require(msg.value >= relayFee + minAckRelayFee, "not enough fee");
        uint256 _ackRelayFee = msg.value - relayFee;

        // check authorization
        address owner = synPkg.creator;
        if (sender != owner) {
            require(hasRole(ROLE_CREATE, owner, sender), "no permission to create");
        }

        // make sure the extra data is as expected
        synPkg.extraData = "";

        // transfer all the fee to tokenHub
        (bool success, ) = TOKEN_HUB.call{ value: address(this).balance }("");
        require(success, "transfer to tokenHub failed");

        emit CreateSubmitted(owner, sender, synPkg.name);

        return (BUCKET_CHANNEL_ID, abi.encodePacked(TYPE_CREATE, abi.encode(synPkg)), relayFee, _ackRelayFee, sender);
    }

    function _prepareCreateBucket(
        address sender,
        CreateBucketSynPackage memory synPkg,
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

        // check package queue
        if (extraData.failureHandleStrategy == FailureHandleStrategy.BlockOnFail) {
            require(retryQueue[sender].empty(), "retry queue is not empty");
        }

        // check authorization
        address _sender = sender;
        {
            address _owner = synPkg.creator;
            string memory _name = synPkg.name;
            if (_sender != _owner) {
                require(hasRole(ROLE_CREATE, _owner, _sender), "no permission to create");
            }

            // make sure the extra data is as expected
            require(extraData.callbackData.length < maxCallbackDataLength, "callback data too long");
            synPkg.extraData = abi.encode(extraData);

            emit CreateSubmitted(_owner, _sender, _name);
        }

        // transfer all the fee to tokenHub
        (bool success, ) = TOKEN_HUB.call{ value: address(this).balance }("");
        require(success, "transfer to tokenHub failed");

        return (BUCKET_CHANNEL_ID, abi.encodePacked(TYPE_CREATE, abi.encode(synPkg)), relayFee, _ackRelayFee, _sender);
    }

    function _prepareDeleteBucket(
        address sender,
        uint256 id
    ) internal returns (uint8, bytes memory, uint256, uint256, address) {
        // check relay fee
        (uint256 relayFee, uint256 minAckRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        require(msg.value >= relayFee + minAckRelayFee, "not enough fee");
        uint256 _ackRelayFee = msg.value - relayFee;

        // check authorization
        CmnDeleteSynPackage memory synPkg;
        {
            address _sender = sender;
            address owner = IERC721NonTransferable(ERC721Token).ownerOf(id);
            if (
                !(_sender == owner ||
                    IERC721NonTransferable(ERC721Token).getApproved(id) == _sender ||
                    IERC721NonTransferable(ERC721Token).isApprovedForAll(owner, _sender))
            ) {
                require(hasRole(ROLE_DELETE, owner, _sender), "no permission to delete");
            }

            synPkg = CmnDeleteSynPackage({ operator: owner, id: id, extraData: "" });

            // transfer all the fee to tokenHub
            (bool success, ) = TOKEN_HUB.call{ value: address(this).balance }("");
            require(success, "transfer to tokenHub failed");

            emit DeleteSubmitted(owner, _sender, id);
        }

        return (BUCKET_CHANNEL_ID, abi.encodePacked(TYPE_DELETE, abi.encode(synPkg)), relayFee, _ackRelayFee, sender);
    }

    function _prepareDeleteBucket(
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

        // check authorization
        address _sender = sender;
        uint256 _id = id;
        address owner = IERC721NonTransferable(ERC721Token).ownerOf(_id);

        // check package queue
        if (extraData.failureHandleStrategy == FailureHandleStrategy.BlockOnFail) {
            require(retryQueue[_sender].empty(), "retry queue is not empty");
        }

        if (
            !(_sender == owner ||
                IERC721NonTransferable(ERC721Token).getApproved(_id) == _sender ||
                IERC721NonTransferable(ERC721Token).isApprovedForAll(owner, _sender))
        ) {
            require(hasRole(ROLE_DELETE, owner, _sender), "no permission to delete");
        }

        // make sure the extra data is as expected
        require(extraData.callbackData.length < maxCallbackDataLength, "callback data too long");
        CmnDeleteSynPackage memory synPkg = CmnDeleteSynPackage({
            operator: owner,
            id: _id,
            extraData: abi.encode(extraData)
        });

        // transfer all the fee to tokenHub
        (bool success, ) = TOKEN_HUB.call{ value: address(this).balance }("");
        require(success, "transfer to tokenHub failed");

        emit DeleteSubmitted(owner, _sender, _id);
        return (BUCKET_CHANNEL_ID, abi.encodePacked(TYPE_DELETE, abi.encode(synPkg)), relayFee, _ackRelayFee, _sender);
    }
}
