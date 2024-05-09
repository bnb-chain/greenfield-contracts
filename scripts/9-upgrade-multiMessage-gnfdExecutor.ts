import {MultiMessageDeployer} from '../typechain-types';
import {setConstantsToConfig, toHuman} from './helper';
import fs from 'fs';
import {execSync} from 'child_process';
import {waitTx} from '../test/helper';

const {ethers, run} = require('hardhat');
const log = console.log;

const main = async () => {
    const commitId = await getCommitId();

    const {chainId} = await ethers.provider.getNetwork();
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
            {gasLimit: 5000000}
        )
    );

    const implCrossChain = await deployContract('CrossChain');
    log('new implCrossChain deployed', implCrossChain.address);

    const implGroupHub = await deployContract('GroupHub');
    log('new implGroupHub deployed', implGroupHub.address);

    const addGroupHub = await deployContract('AdditionalGroupHub');
    log('new addGroupHub deployed', addGroupHub.address);

    const implBucketHub = await deployContract('BucketHub');
    log('new BucketHub deployed', implBucketHub.address);

    const addBucketHub = await deployContract('AdditionalBucketHub');
    log('new addBucketHub deployed', addBucketHub.address);

    const implObjectHub = await deployContract('ObjectHub');
    log('new ObjectHub deployed', implObjectHub.address);

    const addObjectHub = await deployContract('AdditionalObjectHub');
    log('new addObjectHub deployed', addObjectHub.address);

    const implPermissionHub = await deployContract('PermissionHub');
    log('new PermissionHub deployed', implPermissionHub.address);

    const addPermissionHub = await deployContract('AdditionalPermissionHub');
    log('new addPermissionHub deployed', addPermissionHub.address);

    const implTokenHub = await deployContract('TokenHub');
    log('new TokenHub deployed', implTokenHub.address);

    try {
        await run('verify:verify', {
            address: multiMessageDeployer.address,
            constructorArguments: [contracts.Deployer, '0x' + commitId],
        });
        await run('verify:verify', {address: implMultiMessage.address});
        await run('verify:verify', {address: implGreenfieldExecutor.address});
        await run('verify:verify', {address: implCrossChain.address});

        await run('verify:verify', {address: implGroupHub.address});
        await run('verify:verify', {address: addGroupHub.address});
        await run('verify:verify', {address: implBucketHub.address});
        await run('verify:verify', {address: addBucketHub.address});
        await run('verify:verify', {address: implObjectHub.address});
        await run('verify:verify', {address: addObjectHub.address});
        await run('verify:verify', {address: implPermissionHub.address});
        await run('verify:verify', {address: addPermissionHub.address});
        await run('verify:verify', {address: implTokenHub.address});
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
