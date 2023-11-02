import { ethers } from 'ethers';
import 'dotenv/config';

const log = console.log;

let TOKEN_HUB: string;
const BSC_RPC_URL = process.env.RPC_URL || 'https://bsc-dataseed2.ninicoin.io';
const operatorPrivateKey = process.env.OPERATOR_PRIVATE_KEY as string;
const unlockReceiver = process.env.UNLOCK_RECEIVER as string;

if (!operatorPrivateKey) {
    throw new Error('OPERATOR_PRIVATE_KEY is not set on .env');
}

if (!unlockReceiver) {
    throw new Error('UNLOCK_RECEIVER is not set on .env');
}

const provider = new ethers.providers.JsonRpcProvider(BSC_RPC_URL);
const wallet = new ethers.Wallet(operatorPrivateKey, provider);

// TokenHub
const abiTokenHub = ['function withdrawUnlockedToken(address recipient) external'];

const main = async () => {
    const balance = await provider.getBalance(wallet.address);
    if (balance.lt(ethers.utils.parseEther('0.01'))) {
        console.error('Insufficient balance for gas');
    }

    const { chainId } = await provider.getNetwork();
    log('chainId', chainId);
    const contracts: any = require(`../deployment/${chainId}-deployment.json`);
    TOKEN_HUB = contracts.TokenHub;

    log('start work', wallet.address);
    const tokenHub = new ethers.Contract(TOKEN_HUB, abiTokenHub, wallet);

    while (true) {
        try {
            log(new Date().toString(), 'try to withdrawUnlockedToken for', unlockReceiver);
            const tx = await tokenHub.withdrawUnlockedToken(unlockReceiver);
            await tx.wait(1);
        } catch (e: any) {
            log('error', e.error);
        }
        await sleep(10);
    }
};

const sleep = async (seconds: number) => {
    log('sleep', seconds, 's');
    await new Promise((resolve) => setTimeout(resolve, seconds * 1000));
};

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
