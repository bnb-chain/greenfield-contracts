import { PermissionDeployer } from '../typechain-types';
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

    const permissionDeployer = (await deployContract('PermissionDeployer', contracts.Deployer, '0x' + commitId)) as PermissionDeployer;
    contracts.PermissionDeployer = permissionDeployer.address;
    contracts.PermissionHub = await permissionDeployer.proxyPermissionHub();
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
        emergencyOperator: contracts.EmergencyOperator,
        emergencyUpgradeOperator: contracts.EmergencyUpgradeOperator,
    });

    const implPermissionHub = await deployContract('PermissionHub');
    const addPermissionHub = await deployContract('AdditionalPermissionHub');
    const permissionToken = await deployContract(
        'ERC721NonTransferable',
        'GreenField-PermissionToken',
        'PERMISSION',
        'permission',
        contracts.PermissionHub
    );
    log('deploy permission token success', permissionToken.address);

    await waitTx(
        permissionDeployer.deploy(
            implPermissionHub.address,
            addPermissionHub.address,
            permissionToken.address
        )
    );
    contracts.AdditionalPermissionHub = addPermissionHub.address;
    contracts.PermissionToken = permissionToken.address;

    try {
        await run('verify:verify', {
            address: permissionDeployer.address,
            constructorArguments: [contracts.Deployer, '0x' + commitId],
        });
        await run('verify:verify', { address: implPermissionHub.address });
        await run('verify:verify', { address: addPermissionHub.address });
        await run('verify:verify', {
            address: permissionToken.address,
            constructorArguments: [
                'GreenField-Permission',
                'PERMISSION',
                'permission',
                contracts.PermissionHub,
            ],
        });

        log('implPermissionHub addPermissionHub permissionToken contract verified');
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
