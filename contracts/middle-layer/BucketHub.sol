// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "./NFTHub.sol";
import "../interface/IERC721NonTransferable.sol";
import "../interface/ICrossChain.sol";
import "../lib/RLPEncode.sol";
import "../lib/RLPDecode.sol";

contract BucketHub is NFTHub {
    using RLPEncode for *;
    using RLPDecode for *;

    // operation type
    uint8 public constant TYPE_CREATE = 2;
    uint8 public constant TYPE_DELETE = 3;

    /*----------------- struct -----------------*/
    struct CreateSynPackage {
        address creator;
        string name;
        bool isPublic;
        address paymentAddress;
        address primarySpAddress;
        bytes primarySpSignature;
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
     * @dev create a bucket and send cross-chain request from BSC to GNFD
     *
     * @param name The bucket's name
     * @param isPublic The bucket is public or not
     * @param paymentAddress The address of the fee payer
     * @param spAddress The primary sp address that store the bucket resource
     * @param spSignature The primary sp's signature
     */
    function createBucket(
        string calldata name,
        bool isPublic,
        address paymentAddress,
        address spAddress,
        bytes calldata spSignature
    ) external payable returns (bool) {
        require(msg.value >= relayFee + ackRelayFee, "received BNB amount should be no less than the minimum relayFee");
        uint256 _ackRelayFee = msg.value - relayFee;

        CreateSynPackage memory synPkg = CreateSynPackage({
            creator: msg.sender,
            name: name,
            isPublic: isPublic,
            paymentAddress: paymentAddress,
            primarySpAddress: spAddress,
            primarySpSignature: spSignature
        });

        address _crossChain = CROSS_CHAIN;
        ICrossChain(_crossChain).sendSynPackage(
            BUCKET_CHANNEL_ID, _encodeCreateSynPackage(synPkg), relayFee, _ackRelayFee
        );
        emit CreateSubmitted(msg.sender, name, relayFee, _ackRelayFee);
        return true;
    }

    /**
     * @dev delete a bucket and send cross-chain request from BSC to GNFD
     *
     * @param name The bucket's name
     */
    function deleteBucket(string calldata name) external payable returns (bool) {
        require(msg.value >= relayFee + ackRelayFee, "received BNB amount should be no less than the minimum relayFee");
        uint256 _ackRelayFee = msg.value - relayFee;

        CmnDeleteSynPackage memory synPkg = CmnDeleteSynPackage({operator: msg.sender, name: name});

        address _crossChain = CROSS_CHAIN;
        ICrossChain(_crossChain).sendSynPackage(
            BUCKET_CHANNEL_ID, _encodeCmnDeleteSynPackage(synPkg), relayFee, _ackRelayFee
        );
        emit DeleteSubmitted(msg.sender, name, relayFee, _ackRelayFee);
        return true;
    }

    /*----------------- internal function -----------------*/
    function _encodeCreateSynPackage(CreateSynPackage memory synPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](6);
        elements[0] = synPkg.creator.encodeAddress();
        elements[1] = bytes(synPkg.name).encodeBytes();
        elements[2] = synPkg.isPublic.encodeBool();
        elements[3] = synPkg.paymentAddress.encodeAddress();
        elements[4] = synPkg.primarySpAddress.encodeAddress();
        elements[5] = synPkg.primarySpSignature.encodeBytes();
        return _RLPEncode(TYPE_CREATE, elements.encodeList());
    }

    function _encodeCmnDeleteSynPackage(CmnDeleteSynPackage memory synPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](2);
        elements[0] = synPkg.operator.encodeAddress();
        elements[1] = bytes(synPkg.name).encodeBytes();
        return _RLPEncode(TYPE_DELETE, elements.encodeList());
    }
}
