import { BigNumber } from 'ethers';
import {CrossChain, TokenHub} from '../typechain-types';
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

  log('before tx oracle seq: ', (await crossChain.oracleSequence()).toString())
  log('bucket send seq: ', (await crossChain.channelSendSequenceMap(4)).toString())
  log('group send seq: ', (await crossChain.channelSendSequenceMap(6)).toString())



    await waitTx(crossChain.emergencyChangeSequence(false, 4, true, true, 1))
    log('Bucket Channel seq + 1, done!')

    log('after change oracle seq: ', (await crossChain.oracleSequence()).toString())
    log('bucket send seq: ', (await crossChain.channelSendSequenceMap(4)).toString())
    log('group send seq: ', (await crossChain.channelSendSequenceMap(6)).toString())
};

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
