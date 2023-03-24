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

// Highlight: This contract must have the same storage layout as BucketHub
// which means same state variables and same order of state variables.
// Because it will be used as a delegate call target.
// NOTE: The inherited contracts order must be the same as BucketHub.
contract AdditionalBucketHub is NFTWrapResourceStorage, Initializable, AccessControl {
    using DoubleEndedQueueUpgradeable for DoubleEndedQueueUpgradeable.Bytes32Deque;
    using RLPEncode for *;
    using RLPDecode for *;

    // package type
    bytes32 public constant CREATE_BUCKET_SYN = keccak256("CREATE_BUCKET_SYN");

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
        // check relay fee
        (uint256 relayFee, uint256 minAckRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        require(msg.value >= relayFee + minAckRelayFee, "not enough fee");
        uint256 _ackRelayFee = msg.value - relayFee;

        // check authorization
        address owner = synPkg.creator;
        if (msg.sender != owner) {
            require(hasRole(ROLE_CREATE, owner, msg.sender), "no permission to create");
        }

        // make sure the extra data is as expected
        synPkg.extraData = "";

        ICrossChain(CROSS_CHAIN).sendSynPackage(
            BUCKET_CHANNEL_ID,
            _encodeCreateBucketSynPackage(synPkg),
            relayFee,
            _ackRelayFee
        );
        emit CreateSubmitted(owner, msg.sender, synPkg.name);
        return true;
    }

    /**
     * @dev create a bucket and send cross-chain request from BSC to GNFD.
     * Callback function will be called when the request is processed.
     *
     * @param synPkg Package containing information of the bucket to be created
     * @param callbackGasLimit The gas limit for callback function
     * @param extraData Extra data for callback function. The `appAddress` in `extraData` will be ignored.
     * It will be reset as the `msg.sender` all the time.
     */
    function createBucket(
        CreateBucketSynPackage memory synPkg,
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
            require(retryQueue[msg.sender].empty(), "retry queue is not empty");
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
        (bool success, ) = extraData.refundAddress.call("");
        require(success && (extraData.refundAddress != address(0)), "invalid refund address");

        ICrossChain(CROSS_CHAIN).sendSynPackage(
            BUCKET_CHANNEL_ID,
            _encodeCreateBucketSynPackage(synPkg),
            relayFee,
            _ackRelayFee
        );
        emit CreateSubmitted(owner, msg.sender, synPkg.name);
        return true;
    }

    /**
     * @dev delete a bucket and send cross-chain request from BSC to GNFD
     *
     * @param id The bucket's id
     */
    function deleteBucket(uint256 id) external payable returns (bool) {
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
            require(hasRole(ROLE_DELETE, owner, msg.sender), "no permission to delete");
        }

        CmnDeleteSynPackage memory synPkg = CmnDeleteSynPackage({ operator: owner, id: id, extraData: "" });

        ICrossChain(CROSS_CHAIN).sendSynPackage(
            BUCKET_CHANNEL_ID,
            _encodeCmnDeleteSynPackage(synPkg),
            relayFee,
            _ackRelayFee
        );
        emit DeleteSubmitted(owner, msg.sender, id);
        return true;
    }

    /**
     * @dev delete a bucket and send cross-chain request from BSC to GNFD.
     * Callback function will be called when the request is processed.
     *
     * @param id The bucket's id
     * @param callbackGasLimit The gas limit for callback function
     * @param extraData Extra data for callback function. The `appAddress` in `extraData` will be ignored.
     * It will be reset as the `msg.sender` all the time.
     */
    function deleteBucket(
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
            require(hasRole(ROLE_DELETE, owner, msg.sender), "no permission to delete");
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
        require(success && (extraData.refundAddress != address(0)), "invalid refund address");

        ICrossChain(CROSS_CHAIN).sendSynPackage(
            BUCKET_CHANNEL_ID,
            _encodeCmnDeleteSynPackage(synPkg),
            relayFee,
            _ackRelayFee
        );
        emit DeleteSubmitted(owner, msg.sender, id);
        return true;
    }

    function retryPackage() external {
        CallbackPackage memory callbackPkg = getRetryPackage(msg.sender);
        if (callbackPkg.isFailAck) {
            if (callbackPkg.pkgType == CREATE_BUCKET_SYN) {
                (CreateBucketSynPackage memory synPkg, bool success) = _decodeCreateBucketSynPackage(
                    callbackPkg.msgBytes
                );
                require(success, "decode create bucket fail ack package failed");

                IApplication(callbackPkg.appAddress).handleFailAckPackage(channelId, synPkg, callbackPkg.callbackData);

                bytes32 pkgHash = retryQueue[callbackPkg.appAddress].popFront();
                delete packageMap[pkgHash];
            } else if (callbackPkg.pkgType == CMN_DELETE_SYN) {
                (CmnDeleteSynPackage memory synPkg, bool success) = _decodeCmnDeleteSynPackage(callbackPkg.msgBytes);
                require(success, "decode delete bucket fail ack package failed");

                IApplication(callbackPkg.appAddress).handleFailAckPackage(channelId, synPkg, callbackPkg.callbackData);

                bytes32 pkgHash = retryQueue[callbackPkg.appAddress].popFront();
                delete packageMap[pkgHash];
            } else {
                revert("invalid callback package type");
            }
        } else {
            if (callbackPkg.pkgType == CMN_CREATE_ACK) {
                (CmnCreateAckPackage memory ackPkg, bool success) = _decodeCmnCreateAckPackage(callbackPkg.msgBytes);
                require(success, "decode create bucket ack package failed");

                IApplication(callbackPkg.appAddress).handleAckPackage(channelId, ackPkg, callbackPkg.callbackData);

                bytes32 pkgHash = retryQueue[callbackPkg.appAddress].popFront();
                delete packageMap[pkgHash];
            } else if (callbackPkg.pkgType == CMN_DELETE_ACK) {
                (CmnDeleteAckPackage memory ackPkg, bool success) = _decodeCmnDeleteAckPackage(callbackPkg.msgBytes);
                require(success, "decode delete bucket ack package failed");

                IApplication(callbackPkg.appAddress).handleAckPackage(channelId, ackPkg, callbackPkg.callbackData);

                bytes32 pkgHash = retryQueue[callbackPkg.appAddress].popFront();
                delete packageMap[pkgHash];
            } else {
                revert("invalid callback package type");
            }
        }
    }

    /*----------------- internal function -----------------*/
    function _encodeCreateBucketSynPackage(CreateBucketSynPackage memory synPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](9);
        elements[0] = synPkg.creator.encodeAddress();
        elements[1] = bytes(synPkg.name).encodeBytes();
        elements[2] = uint256(synPkg.visibility).encodeUint();
        elements[3] = synPkg.paymentAddress.encodeAddress();
        elements[4] = synPkg.primarySpAddress.encodeAddress();
        elements[5] = synPkg.primarySpApprovalExpiredHeight.encodeUint();
        elements[6] = synPkg.primarySpSignature.encodeBytes();
        elements[7] = uint256(synPkg.chargedReadQuota).encodeUint();
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

    function _decodeCreateBucketSynPackage(
        bytes memory pkgBytes
    ) internal pure returns (CreateBucketSynPackage memory synPkg, bool success) {
        RLPDecode.Iterator memory iter = pkgBytes.toRLPItem().iterator();

        uint256 idx;
        while (iter.hasNext()) {
            if (idx == 0) {
                synPkg.creator = iter.next().toAddress();
            } else if (idx == 1) {
                synPkg.name = string(iter.next().toBytes());
            } else if (idx == 2) {
                synPkg.visibility = BucketVisibilityType(iter.next().toUint());
            } else if (idx == 3) {
                synPkg.paymentAddress = iter.next().toAddress();
            } else if (idx == 4) {
                synPkg.primarySpAddress = iter.next().toAddress();
            } else if (idx == 5) {
                synPkg.primarySpApprovalExpiredHeight = iter.next().toUint();
            } else if (idx == 6) {
                synPkg.primarySpSignature = iter.next().toBytes();
            } else if (idx == 7) {
                synPkg.chargedReadQuota = uint64(iter.next().toUint());
            } else if (idx == 8) {
                synPkg.extraData = iter.next().toBytes();
                success = true;
            } else {
                break;
            }
            idx++;
        }
        return (synPkg, success);
    }
}
