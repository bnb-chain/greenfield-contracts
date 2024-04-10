import { MultiMessageDeployer } from '../typechain-types';
import { setConstantsToConfig, sleep, toHuman } from './helper';
import fs from 'fs';
import { execSync } from 'child_process';
import { waitTx } from '../test/helper';
const { ethers, run } = require('hardhat');
const log = console.log;

const main = async () => {
    const commitId = await getCommitId();

    const { chainId } = await ethers.provider.getNetwork();
    log('chainId', chainId);
    const deployFile = `${__dirname}/../deployment/${chainId}-deployment.json`
    let contracts: any = require(deployFile);

    const [operator] = await ethers.getSigners();
    const balance = await ethers.provider.getBalance(operator.address);
    log('operator.address: ', operator.address, toHuman(balance));

    const multiMessageDeployer = (await deployContract('MultiMessageDeployer', contracts.Deployer, '0x' + commitId)) as MultiMessageDeployer;
    log('multiMessageDeployer deployed', multiMessageDeployer.address);

    contracts.MultiMessageDeployer = multiMessageDeployer.address;
    contracts.MultiMessage = await multiMessageDeployer.proxyMultiMessage();
    contracts.GreenfieldExecutor = await multiMessageDeployer.proxyGreenfieldExecutor();

    await setConstantsToConfig({
        proxyAdmin: contracts.ProxyAdmin,
        proxyGovHub: contracts.GovHub,
        proxyCrossChain: contracts.CrossChain,
        proxyTokenHub: contracts.TokenHub,
        proxyLightClient: contracts.LightClient,
        proxyRelayerHub: contracts.RelayerHub,
        proxyBucketHub: contracts.BucketHub,
        proxyObjectHub: contracts.ObjectHub,
        proxyGroupHub: contracts.GroupHub,
        proxyPermissionHub: contracts.PermissionHub,

        proxyMultiMessage: contracts.MultiMessage,
        proxyGreenfieldExecutor: contracts.GreenfieldExecutor,

        emergencyOperator: contracts.EmergencyOperator,
        emergencyUpgradeOperator: contracts.EmergencyUpgradeOperator,
    });

    const implMultiMessage = await deployContract('MultiMessage');
    log('implMultiMessage deployed', implMultiMessage.address);
    const implGreenfieldExecutor = await deployContract('GreenfieldExecutor');
    log('implGreenfieldExecutor deployed', implGreenfieldExecutor.address);
    await waitTx(
        multiMessageDeployer.deploy(
            implMultiMessage.address,
            implGreenfieldExecutor.address,
            { gasLimit: 5000000 }
        )
    );

    const implCrossChain = await deployContract('CrossChain');
    log('new implCrossChain deployed', implCrossChain.address);

    try {
        await run('verify:verify', {
            address: multiMessageDeployer.address,
            constructorArguments: [contracts.Deployer, '0x' + commitId],
        });
        await run('verify:verify', { address: implMultiMessage.address });
        await run('verify:verify', { address: implGreenfieldExecutor.address });
        await run('verify:verify', { address: implCrossChain.address });
        log('implCrossChain, implMultiMessage and implGreenfieldExecutor contracts verified');
    } catch (e) {
        log('verify error', e);
    }
    fs.writeFileSync(deployFile, JSON.stringify(contracts, null, 2));
};

const getCommitId = async (): Promise<string> => {
    try {
        const result = execSync('git rev-parse HEAD');
        log('getCommitId', result.toString().trim());
        return result.toString().trim();
    } catch (e) {
        console.error('getCommitId error', e);
        return '';
    }
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
