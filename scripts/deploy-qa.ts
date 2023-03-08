import {ConsensusState, deployGreenFieldContracts, toHuman, unit} from "./helper";
import {ethers} from "hardhat";

const log = console.log
const gnfdChainId = 9000;
const bnbUpperLimit = unit.mul(2000_000)
const initConsensusState: ConsensusState = require('./data/consensus-state-qa.json')

const main = async () => {
    const [operator] = await ethers.getSigners();
    const deployment = await deployGreenFieldContracts(gnfdChainId, bnbUpperLimit, initConsensusState)

    // transfer to tokenHub
    // TODO get validators' init bnb balance from greenfield
    const initValidatorsBalance = unit.mul(1_000)
    let tx = await operator.sendTransaction({
        to: deployment.TokenHub,
        value: initValidatorsBalance,
    });
    await tx.wait(1);
    log('transfer BNB to tokenHub', toHuman(initValidatorsBalance))

    // transfer to relayers
    const relayers = initConsensusState.relayers
    for (let i = 0; i < relayers.length; i++) {
        const relayer = ethers.utils.getAddress(relayers[i].address)
        const value = unit.mul(100)
        tx = await operator.sendTransaction({
            to: relayer,
            value,
        });
        await tx.wait(1);
        log('transfer BNB to relayer', relayer, toHuman(value))
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
