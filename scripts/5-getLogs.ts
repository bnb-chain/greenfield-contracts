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

let filename = `get-UpdatedConsensusState`;
// const rpcUrl = 'https://greenfield-bsc-testnet-ap.nodereal.io/';
const rpcUrl = 'https://gnfd-bsc.qa.bnbchain.world';
const provider = new ethers.providers.JsonRpcProvider(rpcUrl);

// 1. light client
const targetContract = '0x603E1BD79259EbcbAaeD0c83eeC09cA0B89a5bcC';
// 2. startBlockNumber
const startBlockNumber = 1;
const endBlockNumber = startBlockNumber + 1;
const tokenDecimal = 18;

// 3. config toAddress and event abi
const interval = process.env.INTERVAL ? parseInt(process.env.INTERVAL) : 5000;

const abi = [
    'event InitConsensusState(uint64 height)',
    'event UpdatedConsensusState(uint64 height, bool validatorSetChanged)',
    'event ReceivedPackage(uint8 packageType, uint64 indexed packageSequence, uint8 indexed channelId)',
    'function deploy(bytes calldata _initConsensusStateBytes)',
    'function syncLightBlock(bytes calldata _lightBlock, uint64 _height)',
    'function handlePackage(bytes calldata _payload,bytes calldata _blsSignature,uint256 _validatorsBitSet)',
];
const iface = new ethers.utils.Interface(abi);
const eventTopic1 = iface.getEventTopic('InitConsensusState');
const eventTopic2 = iface.getEventTopic('UpdatedConsensusState');
const eventTopic3 = iface.getEventTopic('ReceivedPackage');
log('eventTopic', eventTopic1, eventTopic2);

const isWatching = true;
let topics: (string | null | string[])[];

const parseLog = async (result: any, eventlog: Log): Promise<any> => {
    try {
        // 1. parse
        const res = Object.assign({}, iface.parseLog(eventlog));

        // 2. get args from eventLog
        const height = res.args.height.toString();
        const validatorSetChanged = res.args.validatorSetChanged;

        let txHash = eventlog.transactionHash;
        // txHash = SCAN_URL + `/tx/${txHash}`;
        const tx = await provider.getTransaction(txHash);
        const parsedTx = iface.parseTransaction(tx);
        result = result ? result : [];

        if (eventlog.topics[0] === eventTopic1) {
            const _initConsensusStateBytes = parsedTx.args._initConsensusStateBytes;
            result.push({
                eventlog,
                blockNumber: eventlog.blockNumber,
                txHash,
                height,

                eventName: 'InitConsensusState',
                initConsensusStateBytes: _initConsensusStateBytes,
            });
        } else if (eventlog.topics[0] === eventTopic2) {
            const lightBlock = parsedTx.args._lightBlock;
            log('lightBlock', lightBlock);

            // 3. record to storage
            result.push({
                eventlog,
                blockNumber: eventlog.blockNumber,
                txHash,
                height,
                validatorSetChanged,
                lightBlock,
            });
        } else {
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
        }
        return {
            result,
        };
    } catch (e) {
        log(eventlog);
        throw new Error(`Failed to parse log: ${e}`);
    }
};

const main = async () => {
    topics = [[eventTopic1, eventTopic2, eventTopic3]];

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
