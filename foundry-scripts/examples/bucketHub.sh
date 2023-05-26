# 1. create bucket
# set your private-key, bucketName, bucketVisibilityType, paymentAddress, primarySpAddress, primarySpApprovalExpiredHeight, primarySpSignature, chargedReadQuota
# bucketVisibilityType: 0 for Unspecified, 1 for PublicRead, other for private
forge script foundry-scripts/BucketHub.s.sol:BucketHubScript \
--private-key ${your private key} \
--sig "createBucket(string memory bucketName,uint8 bucketVisibilityType,address paymentAddress,address primarySpAddress,uint256 primarySpApprovalExpiredHeight,bytes memory primarySpSignature,uint64 chargedReadQuota)" \
${bucketName} ${bucketVisibilityType} ${paymentAddress} ${primarySpAddress} ${primarySpApprovalExpiredHeight} ${primarySpSignature} ${chargedReadQuota} \
-f https://data-seed-prebsc-1-s1.binance.org:8545/ \
--legacy --ffi --broadcast

# 2. delete bucket
# set your private-key, bucket id to delete
forge script foundry-scripts/BucketHub.s.sol:BucketHubScript \
--private-key ${your private key} \
--sig "deleteBucket(uint256 bucketId)" \
${bucketId to delete} \
-f https://data-seed-prebsc-1-s1.binance.org:8545/ \
--legacy --ffi --broadcast
