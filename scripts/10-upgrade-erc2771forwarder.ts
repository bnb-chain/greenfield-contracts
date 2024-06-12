import { MultiMessageDeployer } from '../typechain-types';
import { setConstantsToConfig, toHuman } from './helper';
import fs from 'fs';
import { execSync } from 'child_process';
import { waitTx } from '../test/helper';

const { ethers, run } = require('hardhat');
const log = console.log;

const main = async () => {
    const { chainId } = await ethers.provider.getNetwork();
    log('chainId', chainId);
    const deployFile = `${__dirname}/../deployment/${chainId}-deployment.json`;
    let contracts: any = require(deployFile);

    const [operator] = await ethers.getSigners();
    const balance = await ethers.provider.getBalance(operator.address);
    log('operator.address: ', operator.address, toHuman(balance));

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

    const implTokenHub = await deployContract('TokenHub');
    log('new implTokenHub deployed', implTokenHub.address);
    const implMultiMessage = await deployContract('MultiMessage');
    log('new implMultiMessage deployed', implMultiMessage.address);
    const implGreenfieldExecutor = await deployContract('GreenfieldExecutor');
    log('new implGreenfieldExecutor deployed', implGreenfieldExecutor.address);


    const addGroupHub = await deployContract('AdditionalGroupHub');
    log('new addGroupHub deployed', addGroupHub.address);

    const addBucketHub = await deployContract('AdditionalBucketHub');
    log('new addBucketHub deployed', addBucketHub.address);

    const addObjectHub = await deployContract('AdditionalObjectHub');
    log('new addObjectHub deployed', addObjectHub.address);

    const addPermissionHub = await deployContract('AdditionalPermissionHub');
    log('new addPermissionHub deployed', addPermissionHub.address);

    try {
        await run('verify:verify', { address: implTokenHub.address });
        await run('verify:verify', { address: implMultiMessage.address });
        await run('verify:verify', { address: implGreenfieldExecutor.address });

        await run('verify:verify', { address: addGroupHub.address });
        await run('verify:verify', { address: addBucketHub.address });
        await run('verify:verify', { address: addObjectHub.address });
        await run('verify:verify', { address: addPermissionHub.address });
        log('contracts verified');
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
