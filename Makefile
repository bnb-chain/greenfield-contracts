.PHONY: build test install-dependencies

include .env

build:
	npx hardhat compile
	forge build

test:
	npm run deploy:test
	npx hardhat test --network test
	forge t -vvvv --ffi

install-dependencies:
	npm install yarn -g
	yarn install
	forge install --no-git --no-commit foundry-rs/forge-std@v1.1.1
	forge install --no-git --no-commit OpenZeppelin/openzeppelin-contracts@v4.8.1
	forge install --no-git --no-commit OpenZeppelin/openzeppelin-contracts-upgradeable@v4.8.1
