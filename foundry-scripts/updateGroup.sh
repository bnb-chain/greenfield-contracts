forge script foundry-scripts/GroupHub.s.sol:GroupHubScript \
--sig "updateGroup(address operator, uint256 groupId, address member)" \
${the owner of the group} ${your group id} ${the member to add} \
-f https://gnfd-bsc-testnet-dataseed1.bnbchain.org \
--private-key ${your private key} \
--legacy \
--broadcast
