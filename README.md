## Prepare
```shell
cp .env.example .env
# modify the env variable `DeployerPrivateKey` to your own private key

yarn install 
forge install --no-git --no-commit foundry-rs/forge-std@v1.1.1
forge install --no-git --no-commit OpenZeppelin/openzeppelin-contracts@v4.8.1
forge install --no-git --no-commit OpenZeppelin/openzeppelin-contracts-upgradeable@v4.8.1
```

## Deploy
```shell
npx hardhat run scripts/deploy.ts --network local
```

## Transaction

```shell
forge script foundry-scripts/TokenHub.s.sol:TokenHubScript  --sig "run(address,address,uint256)" $TokenHub $RECEIPT $AMOUNT  --rpc-url local --private-key $DeployerPrivateKey --legacy --broadcast
```
