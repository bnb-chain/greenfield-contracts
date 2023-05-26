# 1. delete an object
# set your private-key, the object id to delete
forge script foundry-scripts/ObjectHub.s.sol:ObjectHubScript \
--private-key ${your private key} \
--sig "deleteObject(uint256 id)" \
${object id to delete} \
-f https://data-seed-prebsc-1-s1.binance.org:8545/ \
--legacy --ffi --broadcast
