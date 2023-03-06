// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

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
     * @param refundAddress The address to receive the refund of the gas fee
     * @param callbackData The data to be sent back to the application
     */
    function createBucket(CreateSynPackage memory synPkg, address refundAddress, bytes memory callbackData)
        external
        payable
        returns (bool)
    {
        address _appAddress = msg.sender;
        FailureHandleStrategy failStrategy = failureHandleMap[_appAddress];
        require(failStrategy != FailureHandleStrategy.Closed, "application closed");

        require(msg.value >= relayFee + ackRelayFee + callbackGasPrice * CALLBACK_GAS_LIMIT, "not enough relay fee");
        uint256 _ackRelayFee = msg.value - relayFee - callbackGasPrice * CALLBACK_GAS_LIMIT;

        // check package queue
        if (failStrategy == FailureHandleStrategy.HandleInOrder) {
            require(
                packageQueue[_appAddress].length == 0,
                "package queue is not empty, please process the previous package first"
            );
        }

        // check refund address
        (bool success,) = refundAddress.call{gas: transferGas}("");
        require(refundAddress != address(0) & success, "invalid refundAddress"); // the _refundAddress must be payable

        // check authorization
        address owner = synPkg.creator;
        if (msg.sender != owner) {
            require(hasRole(ROLE_CREATE, owner, msg.sender), "no permission to create");
        }

        ExtraData memory extraData = ExtraData({
            appAddress: _appAddress,
            refundAddress: refundAddress,
            failureHandleStrategy: failStrategy,
            callbackData: callbackData
        });
        synPkg.extraData = _extraDataToBytes(extraData);

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
     * @param refundAddress The address to receive the refund of the gas fee
     * @param callbackData The data to be sent back to the application
     */
    function deleteBucket(uint256 id, address refundAddress, bytes memory callbackData)
        external
        payable
        returns (bool)
    {
        address _appAddress = msg.sender;
        FailureHandleStrategy failStrategy = failureHandleMap[_appAddress];
        require(failStrategy != FailureHandleStrategy.Closed, "application closed");

        require(msg.value >= relayFee + ackRelayFee + callbackGasPrice * CALLBACK_GAS_LIMIT, "not enough relay fee");
        uint256 _ackRelayFee = msg.value - relayFee - callbackGasPrice * CALLBACK_GAS_LIMIT;

        // check package queue
        if (failStrategy == FailureHandleStrategy.HandleInOrder) {
            require(
                packageQueue[_appAddress].length == 0,
                "package queue is not empty, please process the previous package first"
            );
        }

        // check refund address
        (bool success,) = refundAddress.call{gas: transferGas}("");
        require(refundAddress != address(0) & success, "invalid refundAddress"); // the _refundAddress must be payable

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

        CmnDeleteSynPackage memory synPkg = CmnDeleteSynPackage({operator: owner, id: id});
        ExtraData memory extraData = ExtraData({
            appAddress: _appAddress,
            refundAddress: refundAddress,
            failureHandleStrategy: failStrategy,
            callbackData: callbackData
        });
        synPkg.extraData = _extraDataToBytes(extraData);

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

    function _extraDataToBytes(ExtraData memory _extraData) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](4);
        elements[0] = _extraData.appAddress.encodeAddress();
        elements[1] = _extraData.refundAddress.encodeAddress();
        elements[2] = uint256(_extraData.failureStrategy).encodeUint();
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
