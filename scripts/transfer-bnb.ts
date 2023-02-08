import { BigNumber } from 'ethers';
const { ethers } = require('hardhat');
const log = console.log;
const contracts: any = require('../deployment/2-GreenField-contracts.json');
const tokenHub = contracts.TokenHub;
const unit = ethers.constants.WeiPerEther;

const main = async () => {
    const [operator] = await ethers.getSigners();
    const balance = await ethers.provider.getBalance(operator.address);
    log('operator.address: ', operator.address, toHuman(balance));

    let tx = await operator.sendTransaction({
        to: tokenHub,
        value: unit.mul(100),
    });
    await tx.wait(1);

    tx = await operator.sendTransaction({
        to: '0xB5EE9c977f4A1679Af2025FD6a1FaC7240c9D50D',
        value: unit.mul(100),
    });
    await tx.wait(1);

    tx = await operator.sendTransaction({
        to: '0xE732055240643AE92A3668295d398C7ddd2dA810',
        value: unit.mul(100),
    });
    await tx.wait(1);
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
