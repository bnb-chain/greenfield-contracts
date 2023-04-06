# Greenfield Contracts
Greenfield Contracts is the bridge between Greenfield and BSC for cross-chain communication.

## Key Features
1. **CrossChain**. The underlying cross-chain communication protocol. This contract is responsible for handling 
all aspects of cross-chain communication packages, including their sending, handling, encoding, and decoding.

2. **GovHub**. This contract oversees all aspects of contract upgrades, parameter adjustments, and handles governance
requests originating from the `Greenfield`. Additionally, it validates and executes governance proposals as required.

3. **TokenHub**. This contract is tasked with handling cross-chain transactions, encompassing both `transferIn` and 
`transferOut`. Upon initiating a cross-chain transfer from the `Greenfield` to the BSC, tokens are initially locked within 
the `TokenHub`, subsequently triggering a cross-chain transfer event. Awaiting a relayer to facilitate the event, 
the transaction is relayed to the `Greenfield`. 

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

## Lint
```shell
yarn lint:check
yarn lint:write
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

## Disclaimer
**The software and related documentation are under active development, all subject to potential future change without
notification and not ready for production use. The code and security audit have not been fully completed and not ready
for any bug bounty. We advise you to be careful and experiment on the network at your own risk. Stay safe out there.**

## Contribution
Thank you for considering helping with the source code! We appreciate contributions from anyone on the internet, no
matter how small the fix may be.

If you would like to contribute to Greenfield, please follow these steps: fork the project, make your changes, commit them,
and send a pull request to the maintainers for review and merge into the main codebase. However, if you plan on submitting
more complex changes, we recommend checking with the core developers first via GitHub issues (we will soon have a Discord channel)
to ensure that your changes align with the project's general philosophy. This can also help reduce the workload of both
parties and streamline the review and merge process.

## License
The greenfield contracts (i.e. all code inside the `contracts` directory) are licensed under the
[GNU Affero General Public License v3.0](https://www.gnu.org/licenses/agpl-3.0.en.html), also
included in our repository in the `COPYING` file.