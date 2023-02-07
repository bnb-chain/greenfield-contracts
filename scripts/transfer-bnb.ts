import {BigNumber} from "ethers";
import {Deployer} from "../typechain-types";

const fs = require('fs')
const {execSync} = require("child_process");
const { ethers } = require('hardhat');

const log = console.log

const gnfdChainId = 1
const init_cs_bytes = '0x677265656e6669656c645f393030302d313231000000000000000000000000000000000000000001a08cee315201a7feb401ba9f312ec3027857b3580f15045f425f44b77bbfc81cb26884f23fb9b226f5f06f8d01018402b3798555359997fcbb9c08b062dcce9800000000000027106e7eaeb9d235d5a0f38d6e3da558bd500f1dff3492789ccca38e43af7040d367f0af050899bbff1114727593759082cc5ff0984089171077f714371877b16d28d56ffe9d42963ecb1e1e4b3e6e2085fcf0d44eedad9c40c5f9b725b115c659cbf0e36d410000000000002710b5ee9c977f4a1679af2025fd6a1fac7240c9d50d8ea2f08235b9cf8b24a030401a1abd3d8df2d53b844acfd0f360de844fce39ccef6899c438f03abf053eca45fde7111b53eadb1084705ef2c90f2a52e46819e8a22937f1cc80f12d7163c8b47c11271f0000000000002710e732055240643ae92a3668295d398c7ddd2da81098a287cb5d67437db9e7559541142e01cc03d5a1866d7d504e522b2fbdcb29d755c1d18c55949b309f2584f0c49c0dcc'

const main = async () => {


}

async function sleep(seconds: number) {
    return new Promise((resolve) => setTimeout(resolve, seconds * 1000));
}

export const toHuman = (x: BigNumber, decimals?: number) => {
    if (!decimals) decimals = 18;
    return ethers.utils.formatUnits(x, decimals);
};


const deployContract = async (factoryPath: string, ...args: any) => {
    const factory = await ethers.getContractFactory(factoryPath);
    const contract = await factory.deploy(...args);
    await contract.deployTransaction.wait(1);
    return contract;
};

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
