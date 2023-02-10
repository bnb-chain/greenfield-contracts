import { ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { GnfdLightClient } from '../typechain-types';
import { expect } from 'chai';
import {waitTx} from "./helper";
import {BigNumber} from "ethers";
const log = console.log;


describe('GnfdLightClient TEST', () => {
    let lightClient: GnfdLightClient;
    let operator: SignerWithAddress;
    let relayer: SignerWithAddress;
    let signers: SignerWithAddress[];

    before('before', async () => {
        signers = await ethers.getSigners();
        operator = signers[0];
        relayer = signers[1];
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

    it('sync light block', async () => {
        const lightBlock = "0x0ac0050a99030a02080b1213677265656e6669656c645f393030302d313231189b18220b08cb99899f061090f7ea632a480a20513530f442d8a58a6aa9e0d1d5a148ae1b51a104deb0124bc5d4725c351c1651122408011220473810f3cf1ab7fe7251a63db7bc930395cdf7b47f14d3e02e113f45a9704de13220d16e3fe969cf51ee33418e08c480a221a086cece527604a8222272d0e0c3791e3a20e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b85542205dc6f15421ac63ee636085b17b079f586b5f14efc9b18fbeb6351dad740c1c134a205dc6f15421ac63ee636085b17b079f586b5f14efc9b18fbeb6351dad740c1c135220048091bc7ddc283f77bfbf91d73c44da58c3df8a9cbc867405d8b7f3daada22f5a20b11fca1db312ece70de1dca3e28d42f3c9fe44789368039bef4ca15d28f404936220e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b8556a20e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b8557214d79bd518ddd84231ff60cc400f039df80544756112a102089b181a480a203a924c9281b8b12d7e1dafa126b05872e1fd2a18d8270ea8d68f5391085d9b2d1224080112200e49954dcafd9c79a6371ce29d0c34327eee87452d8ce7bbfd3c7d667ab28c252268080212142aada08de737c306be8b2616d2280a2633388d361a0c08d099899f0610c0cfc6c5012240acde3c767121f125340695f627c06c54c5971fb32facfd5704a95b8915994c5269dcfdcb3fa9044fb16a64c2fc1ff45d6e269622af1a13e1021fd681c23a4907226808021214d79bd518ddd84231ff60cc400f039df8054475611a0c08d099899f0610a0a0e2f5012240fb1055d85f99639485f621b6f86ee7aad5473d755d2e546aeabaf09335d40f3377e857f33ddc313f5022bea9e26242ce3c6d88b4766079275794679a18ac6d0112b1030a90010a142aada08de737c306be8b2616d2280a2633388d3612220a20b26884f23fb9b226f5f06f8d01018402b3798555359997fcbb9c08b062dcce9818904e20f0b1ffffffffffffff012a3092789ccca38e43af7040d367f0af050899bbff1114727593759082cc5ff0984089171077f714371877b16d28d56ffe9d32146e7eaeb9d235d5a0f38d6e3da558bd500f1dff340a88010a14d79bd518ddd84231ff60cc400f039df80544756112220a2053eadb1084705ef2c90f2a52e46819e8a22937f1cc80f12d7163c8b47c11271f18904e20904e2a3098a287cb5d67437db9e7559541142e01cc03d5a1866d7d504e522b2fbdcb29d755c1d18c55949b309f2584f0c49c0dcc3214e732055240643ae92a3668295d398c7ddd2da8101290010a142aada08de737c306be8b2616d2280a2633388d3612220a20b26884f23fb9b226f5f06f8d01018402b3798555359997fcbb9c08b062dcce9818904e20f0b1ffffffffffffff012a3092789ccca38e43af7040d367f0af050899bbff1114727593759082cc5ff0984089171077f714371877b16d28d56ffe9d32146e7eaeb9d235d5a0f38d6e3da558bd500f1dff34";
        const gasLimit = await lightClient.connect(relayer).estimateGas.syncLightBlock(lightBlock, 3099)
        expect(gasLimit).to.gt(BigNumber.from(0))
    });

});
