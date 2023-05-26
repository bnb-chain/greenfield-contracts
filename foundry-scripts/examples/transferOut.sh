# cross-chain transfer 0.2 BNB (amount = 2 * 10 ^ 17) to your receiver
forge script foundry-scripts/TokenHub.s.sol:TokenHubScript \
--private-key ${your private key} \
--sig "transferOut(address receiver, uint256 amount)" \
${the receiver you transfer to} 200000000000000000  \
-f https://data-seed-prebsc-1-s1.binance.org:8545/  \
--legacy --ffi --broadcast


# cross-chain transfer 5 BNB (amount = 5 * 10 ^ 18) to your receiver
forge script foundry-scripts/TokenHub.s.sol:TokenHubScript \
--private-key ${your private key} \
--sig "transferOut(address receiver, uint256 amount)" \
${the receiver you transfer to} 5000000000000000000  \
-f https://data-seed-prebsc-1-s1.binance.org:8545/  \
--legacy --ffi --broadcast
