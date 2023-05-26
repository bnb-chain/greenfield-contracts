pragma solidity ^0.8.0;

import "./Helper.sol";
contract BucketHubScript is Helper {

    function createBucket(
        string memory bucketName,
        uint8 bucketVisibilityType,
        address paymentAddress,
        address primarySpAddress,
        uint256 primarySpApprovalExpiredHeight,
        bytes memory primarySpSignature,
        uint64 chargedReadQuota
    ) external {
        address creator = tx.origin;
        console.log("creator", creator);

        BucketVisibilityType visibilityType = BucketVisibilityType.Private;
        if (bucketVisibilityType == 0) {
            visibilityType = BucketVisibilityType.Unspecified;
        } else if (bucketVisibilityType == 1) {
            visibilityType = BucketVisibilityType.PublicRead;
        }

        CreateBucketSynPackage memory synPkg = CreateBucketSynPackage(
            creator,
            bucketName,
            visibilityType,
            paymentAddress,
            primarySpAddress,
            primarySpApprovalExpiredHeight,
            primarySpSignature,
            chargedReadQuota,
            ""
        );

        // start broadcast real tx
        vm.startBroadcast();

        bucketHub.createBucket{ value: totalRelayFee }(synPkg);

        vm.stopBroadcast();
    }

    function deleteBucket(uint256 bucketId) external {
        // start broadcast real tx
        vm.startBroadcast();

        bucketHub.deleteBucket{ value: totalRelayFee }(bucketId);

        vm.stopBroadcast();
    }
}
