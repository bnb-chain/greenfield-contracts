// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/DoubleEndedQueueUpgradeable.sol";

import "./storage/ObjectStorage.sol";
import "./utils/GnfdAccessControl.sol";
import "../../interface/IApplication.sol";
import "../../interface/ICrossChain.sol";
import "../../interface/IERC721NonTransferable.sol";

// Highlight: This contract must have the same storage layout as ObjectHub
// which means same state variables and same order of state variables.
// Because it will be used as a delegate call target.
// NOTE: The inherited contracts order must be the same as ObjectHub.
contract AdditionalObjectHub is ObjectStorage, GnfdAccessControl {
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
        if (acCode & AUTH_CODE_DELETE != 0) {
            acCode = acCode & ~AUTH_CODE_DELETE;
            revokeRole(ROLE_DELETE, account);
        }

        require(acCode == 0, "invalid authorization code");
    }

    /**
     * @dev delete a object and send cross-chain request from BSC to GNFD
     *
     * @param id The object id
     */
    function deleteObject(uint256 id) external payable returns (bool) {
        (uint8 _channelId, bytes memory _msgBytes, uint256 _relayFee, uint256 _ackRelayFee, ) = _prepareDeleteObject(
            _erc2771Sender(),
            id
        );
        ICrossChain(CROSS_CHAIN).sendSynPackage(_channelId, _msgBytes, _relayFee, _ackRelayFee);
        return true;
    }

    function prepareDeleteObject(
        address sender,
        uint256 id
    ) external payable onlyMultiMessage returns (uint8, bytes memory, uint256, uint256, address) {
        return _prepareDeleteObject(sender, id);
    }

    /**
     * @dev delete a object and send cross-chain request from BSC to GNFD
     * Callback function will be called when the request is processed
     *
     * @param id The bucket's id
     * @param callbackGasLimit The gas limit for callback function
     * @param extraData Extra data for callback function. The `appAddress` in `extraData` will be ignored.
     * It will be reset to the `msg.sender` all the time. And make sure the `refundAddress` is payable.
     */
    function deleteObject(
        uint256 id,
        uint256 callbackGasLimit,
        ExtraData memory extraData
    ) external payable returns (bool) {
        (uint8 _channelId, bytes memory _msgBytes, uint256 _relayFee, uint256 _ackRelayFee, ) = _prepareDeleteObject(
            _erc2771Sender(),
            id,
            callbackGasLimit,
            extraData
        );

        ICrossChain(CROSS_CHAIN).sendSynPackage(_channelId, _msgBytes, _relayFee, _ackRelayFee);
        return true;
    }

    function prepareDeleteObject(
        address sender,
        uint256 id,
        uint256 callbackGasLimit,
        ExtraData memory extraData
    ) external payable onlyMultiMessage returns (uint8, bytes memory, uint256, uint256, address) {
        return _prepareDeleteObject(sender, id, callbackGasLimit, extraData);
    }

    function _prepareDeleteObject(
        address sender,
        uint256 id
    ) internal returns (uint8, bytes memory, uint256, uint256, address) {
        address owner = IERC721NonTransferable(ERC721Token).ownerOf(id);

        // make sure the extra data is as expected
        CmnDeleteSynPackage memory synPkg = CmnDeleteSynPackage({ operator: owner, id: id, extraData: "" });

        // check relay fee
        (uint256 relayFee, uint256 minAckRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        require(msg.value >= relayFee + minAckRelayFee, "not enough fee");
        uint256 _ackRelayFee = msg.value - relayFee;

        // check authorization
        address _sender = sender;
        if (
            !(_sender == owner ||
                IERC721NonTransferable(ERC721Token).getApproved(id) == _sender ||
                IERC721NonTransferable(ERC721Token).isApprovedForAll(owner, _sender))
        ) {
            require(hasRole(ROLE_DELETE, owner, _sender), "no permission to delete");
        }

        // transfer all the fee to tokenHub
        (bool success, ) = TOKEN_HUB.call{ value: address(this).balance }("");
        require(success, "transfer to tokenHub failed");

        emit DeleteSubmitted(owner, _sender, id);

        return (OBJECT_CHANNEL_ID, abi.encodePacked(TYPE_DELETE, abi.encode(synPkg)), relayFee, _ackRelayFee, _sender);
    }

    function _prepareDeleteObject(
        address sender,
        uint256 id,
        uint256 callbackGasLimit,
        ExtraData memory extraData
    ) internal returns (uint8, bytes memory, uint256, uint256, address) {
        uint256 _id = id;

        // check authorization
        address owner = IERC721NonTransferable(ERC721Token).ownerOf(_id);
        address _sender = sender;
        if (
            !(_sender == owner ||
                IERC721NonTransferable(ERC721Token).getApproved(id) == _sender ||
                IERC721NonTransferable(ERC721Token).isApprovedForAll(owner, _sender))
        ) {
            require(hasRole(ROLE_DELETE, owner, _sender), "no permission to delete");
        }

        // check relay fee and callback fee
        require(callbackGasLimit > 2300, "invalid callback gas limit");
        require(callbackGasLimit <= MAX_CALLBACK_GAS_LIMIT, "invalid callback gas limit");
        (uint256 relayFee, uint256 minAckRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        uint256 callbackGasPrice = ICrossChain(CROSS_CHAIN).callbackGasPrice();
        require(msg.value >= relayFee + minAckRelayFee + callbackGasLimit * callbackGasPrice, "not enough fee");
        uint256 _ackRelayFee = msg.value - relayFee;

        {
            address _owner = owner;
            // check package queue
            if (extraData.failureHandleStrategy == FailureHandleStrategy.BlockOnFail) {
                require(retryQueue[_sender].empty(), "retry queue is not empty");
            }

            // make sure the extra data is as expected
            require(extraData.callbackData.length < maxCallbackDataLength, "callback data too long");

            // check authorization
            if (
                !(_sender == _owner ||
                    IERC721NonTransferable(ERC721Token).getApproved(_id) == _sender ||
                    IERC721NonTransferable(ERC721Token).isApprovedForAll(_owner, _sender))
            ) {
                require(hasRole(ROLE_DELETE, _owner, _sender), "no permission to delete");
            }

            emit DeleteSubmitted(_owner, _sender, _id);

            // transfer all the fee to tokenHub
            (bool success, ) = TOKEN_HUB.call{ value: address(this).balance }("");
            require(success, "transfer to tokenHub failed");
        }

        CmnDeleteSynPackage memory synPkg = CmnDeleteSynPackage({
            operator: owner,
            id: _id,
            extraData: abi.encode(extraData)
        });

        return (OBJECT_CHANNEL_ID, abi.encodePacked(TYPE_CREATE, abi.encode(synPkg)), relayFee, _ackRelayFee, _sender);
    }
}
