import { GnfdLightClient, TokenHub } from '../typechain-types';
import { toHuman } from './helper';
const { ethers } = require('hardhat');
const log = console.log;

const main = async () => {
    const { chainId } = await ethers.provider.getNetwork();
    log('chainId', chainId);
    const contracts: any = require(`../deployment/${chainId}-deployment.json`);

    const [operator] = await ethers.getSigners();
    const balance = await ethers.provider.getBalance(operator.address);
    log('operator.address: ', operator.address, toHuman(balance));

    const tokenHub = (await ethers.getContractAt('TokenHub', contracts.TokenHub)) as TokenHub;
    log('upgradeInfo', await tokenHub.upgradeInfo());

    const lightClient = (await ethers.getContractAt(
        'GnfdLightClient',
        contracts.LightClient
    )) as GnfdLightClient;
    log(await lightClient.upgradeInfo());
};

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
