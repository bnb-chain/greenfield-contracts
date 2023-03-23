# Greenfield Contracts
Greenfield Contracts is the bridge between GreenField and BSC for cross-chain communication.

## Requirement

set environment
```shell
# require Node.js 14+
cp .env.example .env
# modify the env variable `DeployerPrivateKey` to your own private key

# Launch a local test BSC and modify RPC varialbes in .env as your local config
# refer to https://github.com/bnb-chain/node-deploy
# using https://github.com/bnb-chain/bsc-private/tree/ins-precompile as the BSC binary that includes the precompile contracts for BLS features 
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
The greenfield binaries (i.e. all code inside the `contracts` directory) is licensed under the
[GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.en.html), also
included in our repository in the `COPYING` file.
