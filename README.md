## Deploy

```shell
cp .env.example .env
# modify the env variable `PK1` to your own private key 
forge script foundry-scripts/deploy.s.sol:DeployScript  --sig "run()" --rpc-url local --private-key $PK1 --broadcast
```
