import { GnfdLightClient, TokenHub, CrossChain } from '../typechain-types';
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
    log('versionInfo', await tokenHub.versionInfo());

    const lightClient = (await ethers.getContractAt(
        'GnfdLightClient',
        contracts.LightClient
    )) as GnfdLightClient;
    log(await lightClient.versionInfo());

    const crosschain = (await ethers.getContractAt(
        'CrossChain',
        contracts.CrossChain
    )) as CrossChain;

    log('CrossChainPackage', crosschain.interface.getEventTopic('CrossChainPackage'));
    log('ReceivedPackage', crosschain.interface.getEventTopic('ReceivedPackage'));
    log('TransferOutSuccess', tokenHub.interface.getEventTopic('TransferOutSuccess'));
    log('TransferInSuccess', tokenHub.interface.getEventTopic('TransferInSuccess'));
    log('RefundSuccess', tokenHub.interface.getEventTopic('RefundSuccess'));
};

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
