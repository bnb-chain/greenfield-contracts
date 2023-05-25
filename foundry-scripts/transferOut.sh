# cross-chain transfer 0.2 BNB (10 ^ 17) to your receiver

forge script foundry-scripts/TokenHub.s.sol:TokenHubScript \
--sig "transferOut(address receiver, uint256 amount)" \
${the receiver you transfer to} 200000000000000000  \
-f https://data-seed-prebsc-1-s1.binance.org:8545/  \
--private-key ${your private key} \
--legacy --ffi --broadcast
