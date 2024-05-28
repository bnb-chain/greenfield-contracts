// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/DoubleEndedQueueUpgradeable.sol";

import "./storage/PermissionStorage.sol";
import "../../interface/IApplication.sol";
import "../../interface/ICrossChain.sol";
import "../../interface/IERC721NonTransferable.sol";

// Highlight: This contract must have the same storage layout as PermissionHub
// which means same state variables and same order of state variables.
// Because it will be used as a delegate call target.
// NOTE: The inherited contracts order must be the same as PermissionHub.
contract AdditionalPermissionHub is PermissionStorage {
    // PlaceHolder corresponding to `Initializable` contract
    uint8 private _initialized;
    bool private _initializing;

    function createPolicy(bytes calldata _data) external payable returns (bool) {
        (uint8 _channelId, bytes memory _msgBytes, uint256 _relayFee, uint256 _ackRelayFee, ) = _prepareCreatePolicy(
            _erc2771Sender(),
            _data
        );
        ICrossChain(CROSS_CHAIN).sendSynPackage(_channelId, _msgBytes, _relayFee, _ackRelayFee);
        return true;
    }

    function prepareCreatePolicy(
        address sender,
        bytes calldata _data
    ) external payable onlyMultiMessage returns (uint8, bytes memory, uint256, uint256, address) {
        return _prepareCreatePolicy(sender, _data);
    }

    function createPolicy(bytes calldata _data, ExtraData memory _extraData) external payable returns (bool) {
        (uint8 _channelId, bytes memory _msgBytes, uint256 _relayFee, uint256 _ackRelayFee, ) = _prepareCreatePolicy(
            _erc2771Sender(),
            _data,
            _extraData
        );
        ICrossChain(CROSS_CHAIN).sendSynPackage(_channelId, _msgBytes, _relayFee, _ackRelayFee);
        return true;
    }

    function prepareCreatePolicy(
        address sender,
        bytes calldata _data,
        ExtraData memory _extraData
    ) external payable onlyMultiMessage returns (uint8, bytes memory, uint256, uint256, address) {
        return _prepareCreatePolicy(sender, _data, _extraData);
    }

    function deletePolicy(uint256 id) external payable returns (bool) {
        (uint8 _channelId, bytes memory _msgBytes, uint256 _relayFee, uint256 _ackRelayFee, ) = _prepareDeletePolicy(
            _erc2771Sender(),
            id
        );

        ICrossChain(CROSS_CHAIN).sendSynPackage(_channelId, _msgBytes, _relayFee, _ackRelayFee);
        return true;
    }

    /**
     * @dev delete a policy and send cross-chain request from BSC to GNFD
     *
     * @param id The policy id
     * @param _extraData The extra data for crosschain callback
     */
    function deletePolicy(uint256 id, ExtraData memory _extraData) external payable returns (bool) {
        (uint8 _channelId, bytes memory _msgBytes, uint256 _relayFee, uint256 _ackRelayFee, ) = _prepareDeletePolicy(
            _erc2771Sender(),
            id,
            _extraData
        );

        ICrossChain(CROSS_CHAIN).sendSynPackage(_channelId, _msgBytes, _relayFee, _ackRelayFee);
        return true;
    }

    function prepareDeletePolicy(
        address sender,
        uint256 id
    ) external payable onlyMultiMessage returns (uint8, bytes memory, uint256, uint256, address) {
        return _prepareDeletePolicy(sender, id);
    }

    function prepareDeletePolicy(
        address sender,
        uint256 id,
        ExtraData memory extraData
    ) external payable onlyMultiMessage returns (uint8, bytes memory, uint256, uint256, address) {
        return _prepareDeletePolicy(sender, id, extraData);
    }

    function _prepareDeletePolicy(
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
        require(_sender == owner, "invalid operator");

        // make sure the extra data is as expected
        CmnDeleteSynPackage memory synPkg = CmnDeleteSynPackage({ operator: owner, id: id, extraData: "" });

        // transfer all the fee to tokenHub
        (bool success, ) = TOKEN_HUB.call{ value: address(this).balance }("");
        require(success, "transfer to tokenHub failed");

        emit DeleteSubmitted(owner, _sender, id);
        return (
            PERMISSION_CHANNEL_ID,
            abi.encodePacked(TYPE_DELETE, abi.encode(synPkg)),
            relayFee,
            _ackRelayFee,
            _sender
        );
    }

    function _prepareDeletePolicy(
        address sender,
        uint256 id,
        ExtraData memory _extraData
    ) internal returns (uint8, bytes memory, uint256, uint256, address) {
        require(_extraData.failureHandleStrategy == FailureHandleStrategy.SkipOnFail, "only SkipOnFail");

        address _sender = sender;
        // make sure the extra data is as expected
        require(_extraData.callbackData.length < maxCallbackDataLength, "callback data too long");

        // check relay fee
        (uint256 relayFee, uint256 minAckRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        require(msg.value >= relayFee + minAckRelayFee, "not enough fee");
        uint256 _ackRelayFee = msg.value - relayFee;

        // check authorization
        address owner = IERC721NonTransferable(ERC721Token).ownerOf(id);
        require(_sender == owner, "invalid operator");

        // make sure the extra data is as expected
        CmnDeleteSynPackage memory synPkg = CmnDeleteSynPackage({
            operator: owner,
            id: id,
            extraData: abi.encode(_extraData)
        });

        // transfer all the fee to tokenHub
        (bool success, ) = TOKEN_HUB.call{ value: address(this).balance }("");
        require(success, "transfer to tokenHub failed");

        emit DeleteSubmitted(owner, _sender, id);
        return (
            PERMISSION_CHANNEL_ID,
            abi.encodePacked(TYPE_DELETE, abi.encode(synPkg)),
            relayFee,
            _ackRelayFee,
            _sender
        );
    }

    function _prepareCreatePolicy(
        address sender,
        bytes memory _data
    ) internal returns (uint8, bytes memory, uint256, uint256, address) {
        // check relay fee
        (uint256 relayFee, uint256 minAckRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        require(msg.value >= relayFee + minAckRelayFee, "not enough fee");
        uint256 _ackRelayFee = msg.value - relayFee;

        address _sender = sender;
        createPolicySynPackage memory synPkg = createPolicySynPackage({
            operator: _sender,
            data: _data,
            extraData: ""
        });

        // transfer all the fee to tokenHub
        (bool success, ) = TOKEN_HUB.call{ value: address(this).balance }("");
        require(success, "transfer to tokenHub failed");

        emit CreateSubmitted(_sender, _sender, string(_data));
        return (
            PERMISSION_CHANNEL_ID,
            abi.encodePacked(TYPE_CREATE, abi.encode(synPkg, _data)),
            relayFee,
            _ackRelayFee,
            _sender
        );
    }

    function _prepareCreatePolicy(
        address sender,
        bytes memory _data,
        ExtraData memory _extraData
    ) internal returns (uint8, bytes memory, uint256, uint256, address) {
        require(_extraData.failureHandleStrategy == FailureHandleStrategy.SkipOnFail, "only SkipOnFail");

        address _sender = sender;
        // make sure the extra data is as expected
        require(_extraData.callbackData.length < maxCallbackDataLength, "callback data too long");

        // check relay fee
        (uint256 relayFee, uint256 minAckRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        require(msg.value >= relayFee + minAckRelayFee, "not enough fee");
        uint256 _ackRelayFee = msg.value - relayFee;

        createPolicySynPackage memory synPkg = createPolicySynPackage({
            operator: _sender,
            data: _data,
            extraData: abi.encode(_extraData)
        });

        // transfer all the fee to tokenHub
        (bool success, ) = TOKEN_HUB.call{ value: address(this).balance }("");
        require(success, "transfer to tokenHub failed");

        emit CreateSubmitted(_sender, _sender, string(_data));
        return (
            PERMISSION_CHANNEL_ID,
            abi.encodePacked(TYPE_CREATE, abi.encode(synPkg, _data)),
            relayFee,
            _ackRelayFee,
            _sender
        );
    }
}
