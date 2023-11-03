import { Deployer } from '../typechain-types';
import { sleep, toHuman } from './helper';
import fs from 'fs';
import { execSync } from 'child_process';
const { ethers, run } = require('hardhat');
const log = console.log;

const main = async () => {
    const { chainId } = await ethers.provider.getNetwork();
    log('chainId', chainId);
    const contracts: any = require(`../deployment/${chainId}-deployment.json`);

    const [operator] = await ethers.getSigners();
    const balance = await ethers.provider.getBalance(operator.address);
    log('operator.address: ', operator.address, toHuman(balance));

    const deployer = (await ethers.getContractAt('Deployer', contracts.Deployer)) as Deployer;

    try {
        await run('verify:verify', {
            address: contracts.Deployer,
            constructorArguments: [contracts.gnfdChainId, contracts.enableCrossChainTransfer],
        });
    } catch (e) {
        log('verify Deployer error', e);
    }
    const proxyAdmin = await deployer.proxyAdmin();
    const proxyGovHub = await deployer.proxyGovHub();
    const proxyCrossChain = await deployer.proxyCrossChain();
    const proxyTokenHub = await deployer.proxyTokenHub();
    const proxyLightClient = await deployer.proxyLightClient();
    const proxyRelayerHub = await deployer.proxyRelayerHub();
    const proxyBucketHub = await deployer.proxyBucketHub();
    const proxyObjectHub = await deployer.proxyObjectHub();
    const proxyGroupHub = await deployer.proxyGroupHub();

    const config: string = fs
        .readFileSync(__dirname + '/../contracts/Config.sol', 'utf8')
        .toString();
    const newConfig: string = config
        .replace(/PROXY_ADMIN = .*/g, `PROXY_ADMIN = ${proxyAdmin};`)
        .replace(/GOV_HUB = .*/g, `GOV_HUB = ${proxyGovHub};`)
        .replace(/CROSS_CHAIN = .*/g, `CROSS_CHAIN = ${proxyCrossChain};`)
        .replace(/TOKEN_HUB = .*/g, `TOKEN_HUB = ${proxyTokenHub};`)
        .replace(/LIGHT_CLIENT = .*/g, `LIGHT_CLIENT = ${proxyLightClient};`)
        .replace(/RELAYER_HUB = .*/g, `RELAYER_HUB = ${proxyRelayerHub};`)
        .replace(/BUCKET_HUB = .*/g, `BUCKET_HUB = ${proxyBucketHub};`)
        .replace(/OBJECT_HUB = .*/g, `OBJECT_HUB = ${proxyObjectHub};`)
        .replace(/GROUP_HUB = .*/g, `GROUP_HUB = ${proxyGroupHub};`)
        .replace(/EMERGENCY_OPERATOR = .*/g, `EMERGENCY_OPERATOR = ${contracts.EmergencyOperator};`)
        .replace(
            /EMERGENCY_UPGRADE_OPERATOR = .*/g,
            `EMERGENCY_UPGRADE_OPERATOR = ${contracts.EmergencyUpgradeOperator};`
        );

    fs.writeFileSync(__dirname + '/../contracts/Config.sol', newConfig, 'utf8');
    await sleep(2);
    execSync('npx hardhat compile');
    await sleep(2);

    log('For verification, Set all contracts from deployment to Config contract locally');

    const implGovHub = await deployer.implGovHub();
    const implCrossChain = await deployer.implCrossChain();
    const implTokenHub = await deployer.implTokenHub();
    const implLightClient = await deployer.implLightClient();
    const implRelayerHub = await deployer.implRelayerHub();
    const implBucketHub = await deployer.implBucketHub();
    const implObjectHub = await deployer.implObjectHub();
    const implGroupHub = await deployer.implGroupHub();

    const addBucketHub = await deployer.addBucketHub();
    const addObjectHub = await deployer.addObjectHub();
    const addGroupHub = await deployer.addGroupHub();
    const bucketToken = await deployer.bucketToken();
    const objectToken = await deployer.objectToken();
    const groupToken = await deployer.groupToken();
    const memberToken = await deployer.memberToken();

    try {
        await run('verify:verify', { address: implGovHub });
        await run('verify:verify', { address: implCrossChain });
        await run('verify:verify', { address: implTokenHub });
        await run('verify:verify', { address: implLightClient });
        await run('verify:verify', { address: implRelayerHub });
        await run('verify:verify', { address: implBucketHub });
        await run('verify:verify', { address: implObjectHub });
        await run('verify:verify', { address: implGroupHub });
        log('all impl contract verified');
    } catch (e) {
        log('verify error', e);
    }

    try {
        await run('verify:verify', { address: addBucketHub });
        await run('verify:verify', { address: addObjectHub });
        await run('verify:verify', { address: addGroupHub });

        log('verified addBucketHub, addObjectHub, addGroupHub');
    } catch (e) {
        log('verify addBucketHub, addObjectHub, addGroupHub', e);
    }

    try {
        await run('verify:verify', {
            address: proxyGovHub,
            constructorArguments: [implGovHub, proxyAdmin, '0x'],
            contract: 'contracts/GnfdProxy.sol:GnfdProxy',
        });
        await run('verify:verify', {
            address: proxyCrossChain,
            constructorArguments: [implCrossChain, proxyAdmin, '0x'],
            contract: 'contracts/GnfdProxy.sol:GnfdProxy',
        });
        await run('verify:verify', {
            address: proxyTokenHub,
            constructorArguments: [implTokenHub, proxyAdmin, '0x'],
            contract: 'contracts/GnfdProxy.sol:GnfdProxy',
        });
        await run('verify:verify', {
            address: proxyLightClient,
            constructorArguments: [implLightClient, proxyAdmin, '0x'],
            contract: 'contracts/GnfdProxy.sol:GnfdProxy',
        });
        await run('verify:verify', {
            address: proxyRelayerHub,
            constructorArguments: [implRelayerHub, proxyAdmin, '0x'],
            contract: 'contracts/GnfdProxy.sol:GnfdProxy',
        });
        await run('verify:verify', {
            address: proxyBucketHub,
            constructorArguments: [implBucketHub, proxyAdmin, '0x'],
            contract: 'contracts/GnfdProxy.sol:GnfdProxy',
        });
        await run('verify:verify', {
            address: proxyObjectHub,
            constructorArguments: [implObjectHub, proxyAdmin, '0x'],
            contract: 'contracts/GnfdProxy.sol:GnfdProxy',
        });
        await run('verify:verify', {
            address: proxyGroupHub,
            constructorArguments: [implGroupHub, proxyAdmin, '0x'],
            contract: 'contracts/GnfdProxy.sol:GnfdProxy',
        });

        log('all proxy contracts verified');
    } catch (e) {
        log('verify error', e);
    }

    try {
        await run('verify:verify', {
            address: bucketToken,
            constructorArguments: ['GreenField-Bucket', 'BUCKET', 'bucket', proxyBucketHub],
        });
        await run('verify:verify', {
            address: objectToken,
            constructorArguments: ['GreenField-Object', 'OBJECT', 'object', proxyObjectHub],
        });

        await run('verify:verify', {
            address: groupToken,
            constructorArguments: ['GreenField-Group', 'GROUP', 'group', proxyGroupHub],
        });
        await run('verify:verify', {
            address: memberToken,
            constructorArguments: ['member', proxyGroupHub],
        });

        log('bucketToken, objectToken, groupToken, memberToken verified');
    } catch (e) {
        log('verify error, bucketToken, objectToken, groupToken, memberToken', e);
    }
};

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
