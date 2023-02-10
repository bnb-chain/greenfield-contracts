import { BigNumber } from 'ethers';
const { ethers } = require('hardhat');
const log = console.log;
const unit = ethers.constants.WeiPerEther;

const main = async () => {
    const { chainId } = await ethers.provider.getNetwork()
    log('chainId', chainId)
    const contracts: any = require(`../deployment/${ chainId }-deployment.json`)
    const tokenHub = contracts.TokenHub;

    const [operator] = await ethers.getSigners();
    const balance = await ethers.provider.getBalance(operator.address);
    log('operator.address: ', operator.address, toHuman(balance));

    let tx = await operator.sendTransaction({
        to: tokenHub,
        value: unit.mul(100),
    });
    await tx.wait(1);

    const validators = contracts.initConsensusState.validators
    for (let i = 0; i < validators.length; i++) {
        const relayer = validators[i].relayerAddress
        tx = await operator.sendTransaction({
            to: ethers.utils.getAddress(relayer),
            value: unit.mul(100),
        });
        await tx.wait(1);
    }
};

export const toHuman = (x: BigNumber, decimals?: number) => {
    if (!decimals) decimals = 18;
    return ethers.utils.formatUnits(x, decimals);
};

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
