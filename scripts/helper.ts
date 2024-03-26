import { ethers } from 'hardhat';
import { BigNumber } from 'ethers';
import fs from 'fs';
import { execSync } from 'child_process';
import { Deployer } from '../typechain-types';

const log = console.log;

export const unit = ethers.constants.WeiPerEther;

export const toHuman = (x: BigNumber, decimals?: number) => {
    if (!decimals) decimals = 18;
    return ethers.utils.formatUnits(x, decimals);
};

export async function sleep(seconds: number) {
    return new Promise((resolve) => setTimeout(resolve, seconds * 1000));
}

export async function setConstantsToConfig(contracts: any) {
    const proxyAdmin = contracts.proxyAdmin;
    const proxyGovHub = contracts.proxyGovHub;
    const proxyCrossChain = contracts.proxyCrossChain;
    const proxyTokenHub = contracts.proxyTokenHub;
    const proxyLightClient = contracts.proxyLightClient;
    const proxyRelayerHub = contracts.proxyRelayerHub;
    const proxyBucketHub = contracts.proxyBucketHub;
    const proxyObjectHub = contracts.proxyObjectHub;
    const proxyGroupHub = contracts.proxyGroupHub;

    const proxyPermissionHub = contracts.proxyPermissionHub;
    const proxyMultiMessage = contracts.proxyMultiMessage;
    const proxyGreenfieldExecutor = contracts.proxyGreenfieldExecutor;
    const emergencyOperator = contracts.emergencyOperator;
    const emergencyUpgradeOperator = contracts.emergencyUpgradeOperator;

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
        .replace(/PERMISSION_HUB = .*/g, `PERMISSION_HUB = ${proxyPermissionHub};`)
        .replace(/MULTI_MESSAGE = .*/g, `MULTI_MESSAGE = ${proxyMultiMessage};`)
        .replace(/GNFD_EXECUTOR = .*/g, `GNFD_EXECUTOR = ${proxyGreenfieldExecutor};`)
        .replace(/EMERGENCY_OPERATOR = .*/g, `EMERGENCY_OPERATOR = ${emergencyOperator};`)
        .replace(
            /EMERGENCY_UPGRADE_OPERATOR = .*/g,
            `EMERGENCY_UPGRADE_OPERATOR = ${emergencyUpgradeOperator};`
        );
    log('Set all generated contracts to Config contracts');

    fs.writeFileSync(__dirname + '/../contracts/Config.sol', newConfig, 'utf8');
    await sleep(2);
    execSync('npx hardhat compile');
    await sleep(2);
}
