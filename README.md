# Greenfield Contracts
Greenfield Contracts is the bridge between GreenField and BSC for cross-chain communication.

## Prepare

set environment
```shell
cp .env.example .env
# modify the env variable `DeployerPrivateKey` to your own private key

# Launch a local test BSC and modify RPC varialbes in .env as your local config
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

## Build
```shell
make build
```

## Deploy
```shell
# make sure built your local BSC
npm run deploy:test
```

## Test
```shell
# make sure built your local BSC  
make test
```

## License
The library is licensed under the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0),
also included in our repository in the [LICENSE](LICENSE) file.
