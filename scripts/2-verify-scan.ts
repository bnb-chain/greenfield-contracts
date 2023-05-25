import { BigNumber } from 'ethers';
import {Deployer, TokenHub} from '../typechain-types';
import { toHuman } from './helper';
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

    const implGovHub = await deployer.implGovHub();
    const implCrossChain = await deployer.implCrossChain();
    const implTokenHub = await deployer.implTokenHub();
    const implLightClient = await deployer.implLightClient();
    const implRelayerHub = await deployer.implRelayerHub();
    const implBucketHub = await deployer.implBucketHub();
    const implObjectHub = await deployer.implObjectHub();
    const implGroupHub = await deployer.implGroupHub();

    try {
        await run("verify:verify", { address: implGovHub });
        await run("verify:verify", { address: implCrossChain });
        await run("verify:verify", { address: implTokenHub });
        await run("verify:verify", { address: implLightClient });
        await run("verify:verify", { address: implRelayerHub });
        await run("verify:verify", { address: implBucketHub });
        await run("verify:verify", { address: implObjectHub });
        await run("verify:verify", { address: implGroupHub });
        log('all impl contract verified')
    } catch (e) {
        log('verify error', e)
    }

    const addBucketHub = await deployer.addBucketHub()
    const addObjectHub = await deployer.addObjectHub()
    const addGroupHub = await deployer.addGroupHub()
    const bucketToken = await deployer.bucketToken()
    const objectToken = await deployer.objectToken()
    const groupToken = await deployer.groupToken()
    const memberToken = await deployer.memberToken()
    const bucketRlp = await deployer.bucketRlp()
    const objectRlp = await deployer.objectRlp()
    const groupRlp = await deployer.groupRlp()


    try {
        await run("verify:verify", { address: addBucketHub });
        await run("verify:verify", { address: addObjectHub });
        await run("verify:verify", { address: addGroupHub });

        await run("verify:verify", { address: bucketRlp });
        await run("verify:verify", { address: objectRlp });
        await run("verify:verify", { address: groupRlp });
        log('verified addBucketHub, addObjectHub, addGroupHub, bucketRlp, objectRlp, groupRlp')
    } catch (e) {
        log('verify addBucketHub, addObjectHub, addGroupHub, bucketRlp, objectRlp, groupRlp', e)
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

    try {
        await run("verify:verify", {
            address: proxyGovHub,
            constructorArguments: [implGovHub, proxyAdmin, "0x"],
            contract: "GnfdProxy",
        });
        await run("verify:verify", {
            address: proxyCrossChain,
            constructorArguments: [implCrossChain, proxyAdmin, "0x"],
            contract: "GnfdProxy",
        });
        await run("verify:verify", {
            address: proxyTokenHub,
            constructorArguments: [implTokenHub, proxyAdmin, "0x"],
            contract: "GnfdProxy",
        });
        await run("verify:verify", {
            address: proxyLightClient,
            constructorArguments: [implLightClient, proxyAdmin, "0x"],
            contract: "GnfdProxy",
        });
        await run("verify:verify", {
            address: proxyRelayerHub,
            constructorArguments: [implRelayerHub, proxyAdmin, "0x"],
            contract: "GnfdProxy",
        });
        await run("verify:verify", {
            address: proxyBucketHub,
            constructorArguments: [implBucketHub, proxyAdmin, "0x"],
            contract: "GnfdProxy",
        });
        await run("verify:verify", {
            address: proxyObjectHub,
            constructorArguments: [implObjectHub, proxyAdmin, "0x"],
            contract: "GnfdProxy",
        });
        await run("verify:verify", {
            address: proxyGroupHub,
            constructorArguments: [implGroupHub, proxyAdmin, "0x"],
            contract: "GnfdProxy",
        });

        log('all proxy contracts verified')
    } catch (e) {
        log('verify error', e)
    }

};

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
