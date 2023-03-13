// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/DoubleEndedQueueUpgradeable.sol";

import "./AccessControl.sol";
import "./NFTWrapResourceStorage.sol";
import "../interface/ICrossChain.sol";
import "../interface/IERC721NonTransferable.sol";
import "../lib/RLPDecode.sol";
import "../lib/RLPEncode.sol";

// Highlight: This contract must have the same storage layout as BucketHub
// which means same state variables and same order of state variables.
// Because it will be used as a delegate call target.
// NOTE: The inherited contracts order must be the same as BucketHub.
contract AdditionalBucketHub is Initializable, NFTWrapResourceStorage, AccessControl {
    using DoubleEndedQueueUpgradeable for DoubleEndedQueueUpgradeable.Bytes32Deque;
    using RLPEncode for *;
    using RLPDecode for *;

    /*----------------- struct -----------------*/
    // BSC to GNFD
    struct CreateSynPackage {
        address creator;
        string name;
        bool isPublic;
        address paymentAddress;
        address primarySpAddress;
        uint256 primarySpApprovalExpiredHeight;
        bytes primarySpSignature; // TODO if the owner of the bucket is a smart contract, we are not able to get the primarySpSignature
        uint8 readQuota;
        bytes extraData; // rlp encode of ExtraData
    }

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
    function createBucket(CreateSynPackage memory synPkg) external payable returns (bool) {
        // check fee
        require(msg.value >= relayFee + ackRelayFee, "not enough fee");
        uint256 _ackRelayFee = msg.value - relayFee;

        // check authorization
        address owner = synPkg.creator;
        if (msg.sender != owner) {
            require(hasRole(ROLE_CREATE, owner, msg.sender), "no permission to create");
        }

        // make sure the extra data is as expected
        synPkg.extraData = "";

        address _crossChain = CROSS_CHAIN;
        ICrossChain(_crossChain).sendSynPackage(
            BUCKET_CHANNEL_ID, _encodeCreateSynPackage(synPkg), relayFee, _ackRelayFee
        );
        emit CreateSubmitted(owner, msg.sender, synPkg.name, relayFee, _ackRelayFee);
        return true;
    }

    /**
     * @dev create a bucket and send cross-chain request from BSC to GNFD.
     * Callback function will be called when the request is processed.
     *
     * @param synPkg Package containing information of the bucket to be created
     * @param callbackGasLimit Gas limit for callback function
     * @param extraData Extra data for callback function
     */
    function createBucket(CreateSynPackage memory synPkg, uint256 callbackGasLimit, ExtraData memory extraData)
        external
        payable
        returns (bool)
    {
        // check relay fee and callback fee
        require(msg.value >= relayFee + ackRelayFee + callbackGasLimit * tx.gasprice, "not enough fee");
        uint256 _ackRelayFee = msg.value - relayFee - callbackGasLimit * tx.gasprice;

        // check package queue
        if (extraData.failureHandleStrategy == FailureHandleStrategy.HandleInSequence) {
            require(
                retryQueue[msg.sender].length() == 0,
                "retry queue is not empty, please process the previous package first"
            );
        }

        // check authorization
        address owner = synPkg.creator;
        if (msg.sender != owner) {
            require(hasRole(ROLE_CREATE, owner, msg.sender), "no permission to create");
        }

        // make sure the extra data is as expected
        extraData.appAddress = msg.sender;
        synPkg.extraData = _extraDataToBytes(extraData);

        // check refund address
        (bool success,) = extraData.refundAddress.call{gas: transferGas}("");
        require(success && (extraData.refundAddress != address(0)), "invalid refund address");

        address _crossChain = CROSS_CHAIN;
        ICrossChain(_crossChain).sendSynPackage(
            BUCKET_CHANNEL_ID, _encodeCreateSynPackage(synPkg), relayFee, _ackRelayFee
        );
        emit CreateSubmitted(owner, msg.sender, synPkg.name, relayFee, _ackRelayFee);
        return true;
    }

    /**
     * @dev delete a bucket and send cross-chain request from BSC to GNFD
     *
     * @param id The bucket's id
     */
    function deleteBucket(uint256 id) external payable returns (bool) {
        // check fee
        require(msg.value >= relayFee + ackRelayFee, "not enough fee");
        uint256 _ackRelayFee = msg.value - relayFee;

        // check authorization
        address owner = IERC721NonTransferable(ERC721Token).ownerOf(id);
        if (
            !(
                msg.sender == owner || IERC721NonTransferable(ERC721Token).getApproved(id) == msg.sender
                    || IERC721NonTransferable(ERC721Token).isApprovedForAll(owner, msg.sender)
            )
        ) {
            require(hasRole(ROLE_DELETE, owner, msg.sender), "no permission to delete");
        }

        CmnDeleteSynPackage memory synPkg = CmnDeleteSynPackage({operator: owner, id: id, extraData: ""});

        address _crossChain = CROSS_CHAIN;
        ICrossChain(_crossChain).sendSynPackage(
            BUCKET_CHANNEL_ID, _encodeCmnDeleteSynPackage(synPkg), relayFee, _ackRelayFee
        );
        emit DeleteSubmitted(owner, msg.sender, id, relayFee, _ackRelayFee);
        return true;
    }

    /**
     * @dev delete a bucket and send cross-chain request from BSC to GNFD.
     * Callback function will be called when the request is processed.
     *
     * @param id The bucket's id
     * @param callbackGasLimit Gas limit for callback function
     * @param extraData Extra data for callback function
     */
    function deleteBucket(uint256 id, uint256 callbackGasLimit, ExtraData memory extraData)
        external
        payable
        returns (bool)
    {
        // check relay fee and callback fee
        require(msg.value >= relayFee + ackRelayFee + callbackGasLimit * tx.gasprice, "not enough fee");
        uint256 _ackRelayFee = msg.value - relayFee - callbackGasLimit * tx.gasprice;

        // check package queue
        if (extraData.failureHandleStrategy == FailureHandleStrategy.HandleInSequence) {
            require(
                retryQueue[msg.sender].length() == 0,
                "retry queue is not empty, please process the previous package first"
            );
        }

        // check authorization
        address owner = IERC721NonTransferable(ERC721Token).ownerOf(id);
        if (
            !(
                msg.sender == owner || IERC721NonTransferable(ERC721Token).getApproved(id) == msg.sender
                    || IERC721NonTransferable(ERC721Token).isApprovedForAll(owner, msg.sender)
            )
        ) {
            require(hasRole(ROLE_DELETE, owner, msg.sender), "no permission to delete");
        }

        // make sure the extra data is as expected
        extraData.appAddress = msg.sender;
        CmnDeleteSynPackage memory synPkg =
            CmnDeleteSynPackage({operator: owner, id: id, extraData: _extraDataToBytes(extraData)});

        // check refund address
        (bool success,) = extraData.refundAddress.call{gas: transferGas}("");
        require(success && (extraData.refundAddress != address(0)), "invalid refund address");

        address _crossChain = CROSS_CHAIN;
        ICrossChain(_crossChain).sendSynPackage(
            BUCKET_CHANNEL_ID, _encodeCmnDeleteSynPackage(synPkg), relayFee, _ackRelayFee
        );
        emit DeleteSubmitted(owner, msg.sender, id, relayFee, _ackRelayFee);
        return true;
    }

    /*----------------- internal function -----------------*/
    function _encodeCreateSynPackage(CreateSynPackage memory synPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](9);
        elements[0] = synPkg.creator.encodeAddress();
        elements[1] = bytes(synPkg.name).encodeBytes();
        elements[2] = synPkg.isPublic.encodeBool();
        elements[3] = synPkg.paymentAddress.encodeAddress();
        elements[4] = synPkg.primarySpAddress.encodeAddress();
        elements[5] = synPkg.primarySpApprovalExpiredHeight.encodeUint();
        elements[6] = synPkg.primarySpSignature.encodeBytes();
        elements[7] = uint256(synPkg.readQuota).encodeUint();
        elements[8] = synPkg.extraData.encodeBytes();
        return _RLPEncode(TYPE_CREATE, elements.encodeList());
    }

    function _encodeCmnDeleteSynPackage(CmnDeleteSynPackage memory synPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](3);
        elements[0] = synPkg.operator.encodeAddress();
        elements[1] = synPkg.id.encodeUint();
        elements[2] = synPkg.extraData.encodeBytes();
        return _RLPEncode(TYPE_DELETE, elements.encodeList());
    }
}
