import { GreenfieldDemo, ICrossChain } from '../typechain-types';
import { sleep, toHuman } from './helper';
import { deployContract, waitTx } from '../test/helper';
import { ExecutorMsg } from '@bnb-chain/bsc-cross-greenfield-sdk';
import { Policy } from '@bnb-chain/greenfield-cosmos-types/greenfield/permission/types';
import { ResourceType } from '@bnb-chain/greenfield-cosmos-types/greenfield/resource/types';
import {
    ActionType,
    Effect,
    PrincipalType,
} from '@bnb-chain/greenfield-cosmos-types/greenfield/permission/common';
import { Client } from '@bnb-chain/greenfield-js-sdk';
import { ethers } from 'hardhat';

const log = console.log;

const main = async () => {
    const GRPC_URL = 'https://gnfd-testnet-fullnode-tendermint-us.bnbchain.org';
    const GREEN_CHAIN_ID = 'greenfield_5600-1';
    const client = Client.create(GRPC_URL, GREEN_CHAIN_ID);

    const [operator] = await ethers.getSigners();
    log('operator', operator.address);
    const balance = await ethers.provider.getBalance(operator.address);
    log('operator.address: ', operator.address, toHuman(balance));

    // 1. deploy demo contract
    const demo = (await deployContract(operator, 'GreenfieldDemo')) as GreenfieldDemo;
    log('demo contract deployed!', demo.address);
    log(`https://testnet.bscscan.com/address/${demo.address}`);
    const CROSS_CHAIN = await demo.CROSS_CHAIN();
    const crossChain = (await ethers.getContractAt('ICrossChain', CROSS_CHAIN)) as ICrossChain;
    const [relayFee, ackRelayFee] = await crossChain.callStatic.getRelayFees();

    // 2. createBucket
    const bucketName = 'test-' + demo.address.substring(2, 6).toLowerCase();
    // - transferOutAmt: 0.1 BNB to demo contract on Greenfield
    // - set bucket flow rate limit to this bucket
    // - create bucket: 'test-approve-eoa-upload', its owner is demo contract
    const dataSetBucketFlowRateLimit = ExecutorMsg.getSetBucketFlowRateLimitParams({
        bucketName,
        bucketOwner: demo.address,
        operator: demo.address,
        paymentAddress: demo.address,
        flowRateLimit: '1000000000000000000',
    });
    const executorData = dataSetBucketFlowRateLimit[1];
    const transferOutAmt = ethers.utils.parseEther('0.1');
    const value = transferOutAmt.add(relayFee.mul(3).add(ackRelayFee.mul(2)));

    log('- transfer out to demo contract on greenfield', toHuman(transferOutAmt));
    log('- create bucket', bucketName);
    log('send crosschain tx!');
    const receipt = await waitTx(
        demo.createBucket(bucketName, transferOutAmt, executorData, { value })
    );
    log(`https://testnet.bscscan.com/tx/${receipt.transactionHash}`);

    // 3. get bucket id by name
    log('waiting for bucket created..., about 1 minute');
    await sleep(60); // waiting bucket created

    const bucketInfo = await client.bucket.getBucketMeta({ bucketName });
    const bucketId = bucketInfo.body!.GfSpGetBucketMetaResponse.Bucket.BucketInfo.Id;
    log('bucket created, bucket id', bucketId);
    const hexBucketId = `0x000000000000000000000000000000000000000000000000000000000000${BigInt(
        bucketId
    ).toString(16)}`;
    log(`https://testnet.greenfieldscan.com/bucket/${hexBucketId}`);

    const uploaderEoaAccount = operator.address; // TODO set your eoa account to upload files
    log('try to set uploader(eoa account) is', uploaderEoaAccount);

    const policyDataToAllowUserOperateBucket = Policy.encode({
        id: '0',
        resourceId: bucketId, // bucket id
        resourceType: ResourceType.RESOURCE_TYPE_BUCKET,
        statements: [
            {
                effect: Effect.EFFECT_ALLOW,
                actions: [ActionType.ACTION_CREATE_OBJECT], // allow upload file to the bucket
                resources: [],
            },
        ],
        principal: {
            type: PrincipalType.PRINCIPAL_TYPE_GNFD_ACCOUNT,
            value: uploaderEoaAccount,
        },
    }).finish();

    await waitTx(
        demo.createPolicy(policyDataToAllowUserOperateBucket, { value: relayFee.add(ackRelayFee) })
    );

    log(
        `policy set success, ${uploaderEoaAccount} could upload file to the bucket ${bucketName} (id: ${bucketId}) now on Greenfield`
    );
};

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
