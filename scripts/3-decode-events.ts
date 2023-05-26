import {
    Deployer,
    ProxyAdmin,
    GovHub,
    CrossChain,
    TokenHub,
    GnfdLightClient,
    RelayerHub,
} from '../typechain-types';
import { toHuman } from './helper';

const { ethers } = require('hardhat');

const log = console.log;

const InspectTxHashes = ['0x0b95c109a74d7813f8d256a436a5b33a3505c611e238c4127ce5be2db4bac8b6'];

const main = async () => {
    for (let i = 0; i < InspectTxHashes.length; i++) {
        const txHash = InspectTxHashes[i];
        log(i + 1, txHash);
        await decodeTx(txHash);
    }
};

const getLogsFromReceipt = async (txHash: string) => {
    const receipt = await ethers.provider.getTransactionReceipt(txHash);
    return receipt.logs;
};

const decodeTx = async (txHash: string) => {
    const [operator] = await ethers.getSigners();
    const balance = await ethers.provider.getBalance(operator.address);
    const network = await ethers.provider.getNetwork();
    log('network', network);
    log('operator.address: ', operator.address, toHuman(balance));

    const chainId = network.chainId;
    const {
        Deployer,
        ProxyAdmin,
        GovHub,
        CrossChain,
        TokenHub,
        LightClient,
        RelayerHub,
    }: any = require(`../deployment/${chainId}-deployment.json`);

    const deployer = (await ethers.getContractAt('Deployer', Deployer)) as Deployer;
    const proxyAdmin = (await ethers.getContractAt('ProxyAdmin', ProxyAdmin)) as ProxyAdmin;
    const govHub = (await ethers.getContractAt('GovHub', GovHub)) as GovHub;
    const crossChain = (await ethers.getContractAt('CrossChain', CrossChain)) as CrossChain;
    const tokenHub = (await ethers.getContractAt('TokenHub', TokenHub)) as TokenHub;
    const lightClient = (await ethers.getContractAt(
        'GnfdLightClient',
        LightClient
    )) as GnfdLightClient;
    const relayerHub = (await ethers.getContractAt('RelayerHub', RelayerHub)) as RelayerHub;

    const interfaces: any = [];
    interfaces.push({
        name: 'Deployer',
        interface: deployer.interface,
        address: Deployer,
    });
    interfaces.push({
        name: 'ProxyAdmin',
        interface: proxyAdmin.interface,
        address: ProxyAdmin,
    });
    interfaces.push({
        name: 'GovHub',
        interface: govHub.interface,
        address: GovHub,
    });
    interfaces.push({
        name: 'CrossChain',
        interface: crossChain.interface,
        address: CrossChain,
    });
    interfaces.push({
        name: 'TokenHub',
        interface: tokenHub.interface,
        address: TokenHub,
    });
    interfaces.push({
        name: 'LightClient',
        interface: lightClient.interface,
        address: LightClient,
    });
    interfaces.push({
        name: 'RelayerHub',
        interface: relayerHub.interface,
        address: RelayerHub,
    });

    const logs = await getLogsFromReceipt(txHash);
    const tx = await ethers.provider.getTransaction(txHash);
    for (let i = 0; i < logs.length; i++) {
        const eventLog: any = logs[i];
        for (const interfaceObj of interfaces) {
            const iface = interfaceObj.interface;
            if (iface) {
                try {
                    const logDesc = iface.parseLog(eventLog);
                    log('----------------------------------');
                    log('inspect', txHash, 'on block', tx.blockNumber, 'chainId is', tx.chainId);
                    log(interfaceObj.name, 'contract:', eventLog.address);
                    log(logDesc.signature, logDesc.args);
                } catch (e) {}
            }
        }
    }
};

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
