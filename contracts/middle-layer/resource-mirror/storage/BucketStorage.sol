// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "./CmnStorage.sol";

contract BucketStorage is CmnStorage {
    /*----------------- constants -----------------*/
    // package type
    bytes32 public constant CREATE_BUCKET_SYN = keccak256("CREATE_BUCKET_SYN");

    /*----------------- storage -----------------*/
    // PlaceHolder reserve for future use
    uint256[25] public BucketStorageSlots;

    // BSC to GNFD
    struct CreateBucketSynPackage {
        address creator;
        string name;
        BucketVisibilityType visibility;
        address paymentAddress;
        address primarySpAddress;
        uint256 primarySpApprovalExpiredHeight;
        bytes primarySpSignature; // TODO if the owner of the bucket is a smart contract, we are not able to get the primarySpSignature
        uint64 chargedReadQuota;
        bytes extraData; // rlp encode of ExtraData
    }

    enum BucketVisibilityType {
        PublicRead,
        Private,
        Default // If the bucket Visibility is default, it's finally set to private.
    }
}
