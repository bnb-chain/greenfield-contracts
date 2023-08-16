import { Deployer } from '../typechain-types';
import { sleep, toHuman } from './helper';
import fs from 'fs';
import { execSync } from 'child_process';
import {deployContract} from "../test/helper";
const { ethers, run } = require('hardhat');
const log = console.log;

// TODO: add the contract names to be upgraded
const newContractsToUpgrade = [
    'CrossChain',
    'GnfdLightClient',
    'TokenHub',
]

const main = async () => {
    const { chainId } = await ethers.provider.getNetwork();
    log('chainId', chainId);
    const contracts: any = require(`../deployment/${chainId}-deployment.json`);

    const [operator] = await ethers.getSigners();
    const balance = await ethers.provider.getBalance(operator.address);
    log('operator.address: ', operator.address, toHuman(balance));

    const deployer = (await ethers.getContractAt('Deployer', contracts.Deployer)) as Deployer;
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
        .replace(/EMERGENCY_OPERATOR = .*/g, `EMERGENCY_OPERATOR = ${contracts.EmergencyOperator};`);

    fs.writeFileSync(__dirname + '/../contracts/Config.sol', newConfig, 'utf8');
    await sleep(2);
    execSync('npx hardhat compile');
    await sleep(2);

    const targets: string[] = [];
    const newContracts: string[] = [];
    for (let i = 0; i < newContractsToUpgrade.length; i++) {
        let name = newContractsToUpgrade[i];
        const contract = await deployContract(operator, name)
        await contract.deployed();
        log(`new impl of ${name}: ${contract.address}`);
        if (name === "GnfdLightClient") name = "LightClient";
        targets.push(contracts[name]);
        newContracts.push(contract.address);
    }

    log(`key for upgrade:`);
    log(`upgrade`);

    log(`targets for upgrade:`);
    log(`"[${ targets.join(',') }]"`);

    log(`values for upgrade:`);
    log(`"[${ newContracts.join(',') }]"`);



    log(`params of multi-sig call:`);
    log(`key:`);
    log(`upgrade`);

    log(`values:`);
    log('0x' + newContracts.join('').replace(/0x/g, '').toLowerCase());

    log(`targets:`);
    log('0x' + targets.join('').replace(/0x/g, '').toLowerCase());

};

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
