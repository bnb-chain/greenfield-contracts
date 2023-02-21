// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "../ResourceHub.sol";
import "../interface/IERC721NonTransferable.sol";
import "../interface/ICrossChain.sol";
import "../lib/RLPEncode.sol";
import "../lib/RLPDecode.sol";

contract BucketHub is ResourceHub {
    using RLPEncode for *;
    using RLPDecode for *;

    /*----------------- struct -----------------*/
    struct CreateSynPackage {
        address creator;
        string name;
        bool isPublic;
        address paymentAddress;
        address primarySpAddress;
        bytes primarySpSignature;
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
            BUCKET_CHANNELID, _encodeCreateSynPackage(synPkg), relayFee, _ackRelayFee
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

        DeleteSynPackage memory synPkg = DeleteSynPackage({operator: msg.sender, name: name});

        address _crossChain = CROSS_CHAIN;
        ICrossChain(_crossChain).sendSynPackage(
            BUCKET_CHANNELID, _encodeDeleteSynPackage(synPkg), relayFee, _ackRelayFee
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
}
