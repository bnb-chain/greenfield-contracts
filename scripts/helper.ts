import { ethers } from 'hardhat';
import { BigNumber } from 'ethers';

export const unit = ethers.constants.WeiPerEther;

export const toHuman = (x: BigNumber, decimals?: number) => {
    if (!decimals) decimals = 18;
    return ethers.utils.formatUnits(x, decimals);
};

export async function sleep(seconds: number) {
    return new Promise((resolve) => setTimeout(resolve, seconds * 1000));
}
