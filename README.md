## Deploy

```shell
cp .env.example .env
# modify the env variable `PK1` to your own private key 
forge script foundry-scripts/deploy.s.sol:DeployScript  --sig "run(uint16 insChainId)" 48 --rpc-url local --private-key $PK1 --legacy --broadcast
```

## Transaction

```shell
forge script foundry-scripts/crosschain.s.sol:CrossChainScript  --sig "run(bytes calldata _payload, bytes calldata _blsSignature, uint256 _validatorsBitSet)" --rpc-url local --private-key $PK1 --broadcast
```
