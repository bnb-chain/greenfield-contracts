import { BigNumber } from 'ethers';
import {
    Deployer,
    ProxyAdmin,
    GovHub,
    CrossChain,
    TokenHub,
    GnfdLightClient,
    RelayerHub,
} from '../typechain-types';

const { ethers } = require('hardhat');

const log = console.log;
const txHash = '0x8f89394bebc848f31f3837c03b4f8c6ec842389416250225c6d74841d2cfdbc2'

const getLogsFromReceipt = async () => {
    const receipt = await ethers.provider.getTransactionReceipt(txHash)
    return receipt.logs
}

const main = async () => {
    const [operator] = await ethers.getSigners();
    const balance = await ethers.provider.getBalance(operator.address);
    const network = await ethers.provider.getNetwork();
    log('network', network);
    log('operator.address: ', operator.address, toHuman(balance));

    const chainId = network.chainId
    const {
        Deployer,
        ProxyAdmin,
        GovHub,
        CrossChain,
        TokenHub,
        LightClient,
        RelayerHub,
    }: any = require(`../deployment/${ chainId }-deployment.json`)

    const deployer = (await ethers.getContractAt('Deployer', Deployer)) as Deployer;
    const proxyAdmin = (await ethers.getContractAt('ProxyAdmin', ProxyAdmin)) as ProxyAdmin;
    const govHub = (await ethers.getContractAt('GovHub', GovHub)) as GovHub;
    const crossChain = (await ethers.getContractAt('CrossChain', CrossChain)) as CrossChain;
    const tokenHub = (await ethers.getContractAt('TokenHub', TokenHub)) as TokenHub;
    const lightClient = (await ethers.getContractAt('GnfdLightClient', LightClient)) as GnfdLightClient;
    const relayerHub = (await ethers.getContractAt('RelayerHub', RelayerHub)) as RelayerHub;

    const interfaceMap: any = {}
    interfaceMap[Deployer] = deployer.interface
    interfaceMap[ProxyAdmin] = proxyAdmin.interface
    interfaceMap[GovHub] = govHub.interface
    interfaceMap[CrossChain] = crossChain.interface
    interfaceMap[TokenHub] = tokenHub.interface
    interfaceMap[LightClient] = lightClient.interface
    interfaceMap[RelayerHub] = relayerHub.interface

    const logs = await getLogsFromReceipt()

    for (let i = 0; i < logs.length; i++) {
        const eventLog: any = logs[i]
        const iface = interfaceMap[eventLog.address]
        if (iface) {
            log('----------------------------------')
            log('contract:', eventLog.address)
            try {
                const logDesc = iface.parseLog(eventLog)
                log(logDesc.signature, logDesc.args)
            } catch (e) {}
        }
    }
};

export const toHuman = (x: BigNumber, decimals?: number) => {
    if (!decimals) decimals = 18;
    return ethers.utils.formatUnits(x, decimals);
};

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
