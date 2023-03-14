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

    let tx = await operator.sendTransaction({
        to: tokenHub,
        value: unit.mul(10000),
    });
    await tx.wait(1);

    const validators = contracts.initConsensusState.vals;
    for (let i = 0; i < validators.length; i++) {
        const relayer = validators[i].relayerAddress;
        tx = await operator.sendTransaction({
            to: ethers.utils.getAddress(relayer),
            value: unit.mul(100),
        });
        await tx.wait(1);
    }
};

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
