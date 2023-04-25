import { ethers } from 'ethers';
import { startStatistic, toHuman } from './helper';
import { Log } from '@ethersproject/abstract-provider';

const log = console.log;
/*
const addressToBytes32 = (address: string) => {
    return ethers.utils.hexZeroPad(address, 32);
};

const bytes32ToAddress = (bytes32Str: string) => {
    return bytes32Str.replace('0x000000000000000000000000', '0x');
};
*/

let filename = `get-ReceivedPackage`;
// const rpcUrl = 'https://greenfield-bsc-testnet-ap.nodereal.io/';
const rpcUrl = 'https://gnfd-bsc.qa.bnbchain.world';
const provider = new ethers.providers.JsonRpcProvider(rpcUrl);

// 1. light client
const targetContract = '0xeEBe00Ac0756308ac4AaBfD76c05c4F3088B8883';
// 2. startBlockNumber
const startBlockNumber = 127678;
const endBlockNumber = startBlockNumber + 1;

// 3. config toAddress and event abi
const interval = process.env.INTERVAL ? parseInt(process.env.INTERVAL) : 5000;

const abi = [
    'event ReceivedPackage(uint8 packageType, uint64 indexed packageSequence, uint8 indexed channelId)',
    'function handlePackage(bytes calldata _payload,bytes calldata _blsSignature,uint256 _validatorsBitSet)',
];
const iface = new ethers.utils.Interface(abi);
const eventTopic1 = iface.getEventTopic('ReceivedPackage');
log('eventTopic', eventTopic1);

const isWatching = true;
let topics: (string | null | string[])[];

const parseLog = async (result: any, eventlog: Log): Promise<any> => {
    try {
        // 1. parse
        const res = Object.assign({}, iface.parseLog(eventlog));

        let txHash = eventlog.transactionHash;
        // txHash = SCAN_URL + `/tx/${txHash}`;
        const tx = await provider.getTransaction(txHash);
        const parsedTx = iface.parseTransaction(tx);
        result = result ? result : [];

        const _payload = parsedTx.args._payload;
        const _blsSignature = parsedTx.args._blsSignature;
        const _validatorsBitSet = parsedTx.args._validatorsBitSet;

        // 3. record to storage
        result.push({
            eventlog,
            blockNumber: eventlog.blockNumber,
            txHash,
            _payload,
            _blsSignature,
            _validatorsBitSet,
        });
        return {
            result,
        };
    } catch (e) {
        log(eventlog);
        throw new Error(`Failed to parse log: ${e}`);
    }
};

const main = async () => {
    topics = [[eventTopic1]];

    log(`Start get totalDeposit for: ${targetContract}, interval: ${interval}`);

    // 4. config getLogs params
    await startStatistic(
        provider,

        filename,
        parseLog,
        startBlockNumber,
        endBlockNumber,
        targetContract,
        topics,
        interval,
        isWatching
    );
};

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
