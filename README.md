# Greenfield Contracts
Greenfield Contracts is the bridge between GreenField and BSC for cross-chain communication.

## Prepare

set environment
```shell
cp .env.example .env
# modify the env variable `DeployerPrivateKey` to your own private key

# Launch a local test BSC
```

Install foundry:
```shell script
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Install dependency:
```shell
npm install yarn -g
yarn install
forge install --no-git --no-commit foundry-rs/forge-std@v1.1.1
forge install --no-git --no-commit OpenZeppelin/openzeppelin-contracts@v4.8.1
forge install --no-git --no-commit OpenZeppelin/openzeppelin-contracts-upgradeable@v4.8.1
```

## Build
```shell
npx hardhat build
forge build
```

## Deploy
```shell
# make sure built your local BSC
RPC_TEST=http://localhost:8545 npm run deploy:test
```

## Test
```shell
# make sure built your local BSC  
RPC_TEST=http://localhost:8545 npm run deploy:test
npx hardhat test --network test
forge t -vvvv --ffi
```

## License
The library is licensed under the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0),
also included in our repository in the [LICENSE](LICENSE) file.
