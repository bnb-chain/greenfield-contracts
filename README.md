## Code Format
```shell
forge fmt
```

## Env
```shell
cp .env.example .env
# modify the env variable `PK1` to your own private key
```

## Deploy
```shell
forge script foundry-scripts/Deploy.s.sol:DeployScript  --sig "run(uint16 insChainId)" 1 --rpc-url local --private-key $PK1 --legacy --broadcast
```

## Transaction

```shell
forge script foundry-scripts/TokenHub.s.sol:TokenHubScript  --sig "run(address,address,uint256)" $TokenHub $RECEIPT $AMOUNT  --rpc-url local --private-key $PK1 --legacy --broadcast
```
