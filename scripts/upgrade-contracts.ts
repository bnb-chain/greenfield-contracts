import { BigNumber } from 'ethers';
import { Deployer } from '../typechain-types';

const fs = require('fs');
const { ethers } = require('hardhat');
const log = console.log;
const gnfdChainId = 18;
const main = async () => {
    const [operator] = await ethers.getSigners();
    const balance = await ethers.provider.getBalance(operator.address);
    const network = await ethers.provider.getNetwork();
    log('network', network);
    const deployment = require(`../deployment/${network.chainId}-deployment.json`)

    log('operator.address: ', operator.address, toHuman(balance));
    const deployer = (await ethers.getContractAt('Deployer', deployment.Deployer)) as Deployer;

    const implGovHub = await deployContract('GovHub');
    log('deploy implGovHub success', implGovHub.address);

    const implCrossChain = await deployContract('CrossChain');
    log('deploy implCrossChain success', implCrossChain.address);


    const upgrade: any = {
        Deployer: deployer.address,
        implGovHub: implGovHub.address,
        implCrossChain: implCrossChain.address,
        gnfdChainId,
    };
    log('all contracts', upgrade);

    const deploymentDir = __dirname + `/../deployment`;
    if (!fs.existsSync(deploymentDir)) {
        fs.mkdirSync(deploymentDir, { recursive: true });
    }
    fs.writeFileSync(
        `${deploymentDir}/${network.chainId}-upgrade.json`,
        JSON.stringify(upgrade, null, 2)
    );
};

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
