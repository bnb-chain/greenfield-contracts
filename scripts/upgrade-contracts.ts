import { BigNumber } from 'ethers';
import {CrossChain, Deployer, GnfdLightClient, RelayerHub, TokenHub} from '../typechain-types';
import {expect} from "chai";

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
    const implCrossChain = (await deployContract('CrossChain')) as CrossChain;
    const implTokenHub = (await deployContract('TokenHub')) as TokenHub;
    const implLightClient = (await deployContract('GnfdLightClient')) as GnfdLightClient;
    const implRelayerHub = (await deployContract('RelayerHub')) as RelayerHub;

    if (
        await implCrossChain.PROXY_ADMIN() !== deployment.ProxyAdmin ||
        await implCrossChain.CROSS_CHAIN() !== deployment.CrossChain ||
        await implCrossChain.GOV_HUB() !== deployment.GovHub ||
        await implCrossChain.TOKEN_HUB() !== deployment.TokenHub ||
        await implCrossChain.LIGHT_CLIENT() !== deployment.LightClient ||
        await implCrossChain.RELAYER_HUB() !== deployment.RelayerHub
    ) {
        log("Error", "contracts constants of current Config and previous Config mismatch, Please modify Config contract")
        return
    }

    log('deploy implGovHub success', implGovHub.address);
    log('deploy implCrossChain success', implCrossChain.address);
    log('deploy implTokenHub success', implTokenHub.address);
    log('deploy implLightClient success', implLightClient.address);
    log('deploy implRelayerHub success', implRelayerHub.address);

    const upgrade: any = {
        Deployer: deployer.address,
        implGovHub: implGovHub.address,
        implCrossChain: implCrossChain.address,
        implTokenHub: implTokenHub.address,
        implLightClient: implLightClient.address,
        implRelayerHub: implRelayerHub.address,
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
