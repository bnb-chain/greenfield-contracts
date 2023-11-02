import { BigNumber } from 'ethers';
import { TokenHub } from '../typechain-types';
import { toHuman } from './helper';
const { ethers } = require('hardhat');
const log = console.log;

const main = async () => {
    const { chainId } = await ethers.provider.getNetwork();
    log('chainId', chainId);
    const contracts: any = require(`../deployment/${chainId}-deployment.json`);

    const [operator] = await ethers.getSigners();
    const balance = await ethers.provider.getBalance(operator.address);
    log('operator.address: ', operator.address, toHuman(balance));

    const tokenHub = (await ethers.getContractAt('TokenHub', contracts.TokenHub)) as TokenHub;

    const receiver = '0x0000000000000000000000000000000000001001';
    const amount = BigNumber.from(1234567);
    const relayFee = BigNumber.from(4e15);
    const tx = await tokenHub.transferOut(receiver, amount, {
        value: amount.add(relayFee),
        gasPrice: 21e9,
    });
    const receipt = await tx.wait(5);
    log('txHash', tx.hash);
    log('blockNumber', receipt.blockNumber);
};

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
