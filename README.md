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

```
forge script foundry-scripts/TokenHub.s.sol:TokenHubScript  --sig "run(a``ddress,address,uint256)" 0x5a728a312897900d71Fa95F14468056E0c198F16 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 123456789  --rpc-url local --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast
```
