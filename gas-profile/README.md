## Requirement

set environment
```shell
# require Node.js 14+
cp .env.example .env
# modify the env variable `DeployerPrivateKey` to your own private key
# modify the env variable `BSC_TESTNET_RPC` to an archive TESTNET RPC endpoint

# make sure the address corresponding to the private key has enough tBNB in the BSC Testnet
```

Install foundry:
```shell script
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Install dependencies:
```shell
make install-dependencies
```

Export Gas Profile Traces:
```shell
forge test --match-contract ReplayTxTest -vvvvv --ffi
```
