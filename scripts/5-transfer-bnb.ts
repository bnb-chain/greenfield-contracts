import { toHuman, unit } from './helper';
const { ethers } = require('hardhat');
const log = console.log;

const main = async () => {
    const { chainId } = await ethers.provider.getNetwork();
    log('chainId', chainId);
    const contracts: any = require(`../deployment/${chainId}-deployment.json`);
    const tokenHub = contracts.TokenHub;

    const [operator] = await ethers.getSigners();
    const balance = await ethers.provider.getBalance(operator.address);
    log('operator.address: ', operator.address, toHuman(balance));

    let tx;

    const hubBalance = await ethers.provider.getBalance(tokenHub);
    if (hubBalance.lt(unit.mul(5))) {
        tx = await operator.sendTransaction({
            to: tokenHub,
            value: unit.mul(5),
        });
        await tx.wait(1);
    }

    const tester = '0x96D904C0e47e6477C4416369a9858f6E57B317eC';
    const testBalance = await ethers.provider.getBalance(tester);
    if (testBalance.lt(unit.mul(5))) {
        tx = await operator.sendTransaction({
            to: tokenHub,
            value: unit.mul(5),
        });
        await tx.wait(1);
        log('transfer to ', tester, '5 BNB');
    }
    /*
    const validators = contracts.initConsensusState.validators;
    for (let i = 0; i < validators.length; i++) {
        const relayer = validators[i].relayerAddress;
        tx = await operator.sendTransaction({
            to: ethers.utils.getAddress(relayer),
            value: unit.mul(100),
        });
        await tx.wait(1);
    }
    */
};

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
