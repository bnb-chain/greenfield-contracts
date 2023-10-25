import { BigNumber } from 'ethers';
import {CrossChain, GroupHub, TokenHub} from '../typechain-types';
import { toHuman } from './helper';
import {waitTx} from "../test/helper";
const { ethers } = require('hardhat');
const log = console.log;

const main = async () => {
    const { chainId } = await ethers.provider.getNetwork();
    log('chainId', chainId);
    const contracts: any = require(`../deployment/${chainId}-deployment.json`);

    const [operator] = await ethers.getSigners();
    const balance = await ethers.provider.getBalance(operator.address);
    log('operator.address: ', operator.address, toHuman(balance));

    const crossChain = (await ethers.getContractAt('CrossChain', contracts.CrossChain)) as CrossChain;
    log(await crossChain.versionInfo())

    const groupHub = (await ethers.getContractAt('GroupHub', contracts.GroupHub)) as GroupHub;
    log(await groupHub.versionInfo())

    log('before tx oracle seq: ', (await crossChain.oracleSequence()).toString())
    log('bucket send seq: ', (await crossChain.channelSendSequenceMap(4)).toString())
    log('group send seq: ', (await crossChain.channelSendSequenceMap(6)).toString())


    await waitTx(groupHub["createGroup(address,string)"](operator.address, 'testGroup1', { value: 1e18 }))
    log('createGroup, done!', 'group owner', operator.address, 'group name', 'testGroup1')


    log('after tx oracle seq: ', (await crossChain.oracleSequence()).toString())
    log('bucket send seq: ', (await crossChain.channelSendSequenceMap(4)).toString())
    log('group send seq: ', (await crossChain.channelSendSequenceMap(6)).toString())

};

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
