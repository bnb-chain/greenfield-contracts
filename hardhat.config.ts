import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import 'dotenv/config';


const config: HardhatUserConfig = {
    solidity: "0.8.17",

    networks: {
        'test': {
            url: process.env.RPC_TEST || "http://127.0.0.1:8545",
            accounts: [
                process.env.DeployerPrivateKey || '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',  // developer
                process.env.RelayerPrivateKey || '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d',  // relayer
            ]
        },
        'local': {
            url: process.env.BSC_LOCAL || "http://127.0.0.1:8545",
            accounts: [
                process.env.DeployerPrivateKey || '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',  // developer
                process.env.RelayerPrivateKey || '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d',  // relayer
            ]
        },
        'bsc-testnet': {
            url: process.env.BSC_TESTNET_RPC || 'https://data-seed-prebsc-1-s1.binance.org:8545/',
            accounts: [
                process.env.DeployerPrivateKey || '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',  // developer
            ]
        },
        'bsc': {
            url: process.env.BSC_RPC || 'https://bsc-dataseed1.binance.org',
            accounts: [
                process.env.DeployerPrivateKey || '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',  // developer
            ]
        },
    }
};

export default config;
