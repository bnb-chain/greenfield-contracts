import { ethers } from 'hardhat';
import {
    deployContract,
    waitTx,
    validatorUpdateRlpEncode,
    buildSyncPackagePrefix,
    serializeGovPack,
    mineBlocks,
    buildTransferInPackage,
    toRpcQuantity,
    latest,
    increaseTime,
} from './helper';

import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { GnfdLightClient } from '../typechain-types';
import { expect } from 'chai';
const log = console.log;


describe('GnfdLightClient TEST', () => {
    const unit = ethers.constants.WeiPerEther;
    let lightClient: GnfdLightClient;
    let operator: SignerWithAddress;
    let signers: SignerWithAddress[];

    before('before', async () => {
        signers = await ethers.getSigners();
        operator = signers[0];
        log('operator', operator.address)

        const { chainId } = await ethers.provider.getNetwork()
        log('chainId', chainId)


        const deployment: any = require(`../deployment/${ chainId }-deployment.json`)
        lightClient = (await ethers.getContractAt(
            'GnfdLightClient',
            deployment.LightClient
        )) as GnfdLightClient
    });

    beforeEach('beforeEach', async () => {});

    it('query info', async () => {
        log('gnfdHeight', await lightClient.gnfdHeight())
    });

    it('verify package', async () => {
        const payload = '0x00010002010000000000000003000000000063ddf59300000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000eb7b9476d244ce05c3de4bbc6fdd7f56379b145709ade9941ac642f1329404e04850e1dee5e0abe903e62211';
        const sig = '0xa7fb2ddd7b3e710c8ea015cdfd453ddb4ffc6d4f7654daa40bb26b4184aa681bae8250b6edb0f8ec126a0ec964a38d400ee76ba37fe8645b2c4fb353e472e4da47cf88959b1777d7a3aca5b755bbcf967e0506b94158d403a53fdd02acc50e62';
        const bitmap = 7;
        const success = await lightClient.verifyPackage(payload, sig, bitmap)
        expect(success).to.eq(true)
    });

});
