import { ethers } from 'ethers';
import { BigNumber } from 'ethers';
import fs from 'fs';
import { Log } from '@ethersproject/abstract-provider';
import { JsonRpcProvider } from '@ethersproject/providers';
const log = console.log;

export const unit = ethers.constants.WeiPerEther;

export const toHuman = (x: BigNumber, decimals?: number) => {
    if (!decimals) decimals = 18;
    return ethers.utils.formatUnits(x, decimals);
};

export async function sleep(seconds: number) {
    return new Promise((resolve) => setTimeout(resolve, seconds * 1000));
}

export interface Statistic {
    name: string;
    fromBlock: number;
    endBlock: number;
    currentBlock: number;
    result: any;
}

export const startStatistic = async (
    provider: JsonRpcProvider,

    name: string,
    parseLog: (results: any, log: Log) => any,
    fromBlock?: number,
    endBlock?: number,
    contractAddress?: string,
    topics?: (string | null | string[])[],
    intervalBlocks = 200,
    isWatching = false
) => {
    const dataDir = __dirname + '/../data/' + name;
    if (!fs.existsSync(dataDir)) {
        fs.mkdirSync(dataDir, { recursive: true });
    }

    const file = dataDir + '/' + name + '.json';

    let data: Statistic;
    if (!fs.existsSync(file)) {
        asserts(fromBlock, 'fromBlock is required');
        asserts(endBlock, 'endBlock is required');
        data = {
            name: name,
            fromBlock,
            endBlock,
            currentBlock: fromBlock,
        } as Statistic;
        fs.writeFileSync(file, JSON.stringify(data, null, 2));
    } else {
        data = require(file) as Statistic;
        endBlock = data.endBlock;
    }
    let { currentBlock } = data;

    log(`${name} getLogs start at currentBlock`, currentBlock);
    asserts(currentBlock, 'currentBlock is required');
    asserts(endBlock, 'endBlock is required');

    if (isWatching) {
        endBlock = await provider.getBlockNumber();
        data.endBlock = endBlock;
        log(`currentBlock ${currentBlock}, endBlock ${endBlock}`);
    }

    let logs: Log[];
    let i = currentBlock;
    while (true) {
        if (i > endBlock) {
            if (isWatching) {
                i = endBlock;
                endBlock = await provider.getBlockNumber();
                data.endBlock = endBlock;
                log(`currentBlock ${currentBlock}, endBlock ${endBlock}`);
            } else {
                break;
            }
        }

        const fromBlock = i;
        const toBlock = Math.min(i + intervalBlocks - 1, endBlock);
        while (true) {
            try {
                // getLogs
                logs = await provider.getLogs({
                    fromBlock,
                    toBlock,
                    address: contractAddress,
                    topics,
                });

                // logs
                let cnt = 0;
                for (const eventLog of logs) {
                    const { result } = await parseLog(data.result, eventLog);
                    data.result = result;
                }

                // set current block
                data.currentBlock = toBlock + 1;

                // write to file
                log(`${fromBlock} ~ ${toBlock}, find ${logs.length} logs `);
                if (logs.length > 0) {
                    fs.writeFileSync(file, JSON.stringify(data, null, 2));
                }
                break;
            } catch (e) {
                const seconds = 5;
                log(`error: ${e}, retry after ${seconds}s`);
                await sleep(seconds);
            }
        }

        i += intervalBlocks;
    }
};

export function asserts(x: unknown, message = 'not valid'): asserts x {
    if (!x) throw new Error(message);
}
