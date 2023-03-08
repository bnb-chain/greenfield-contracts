import {ConsensusState, deployGreenFieldContracts, unit} from "./helper";
const log = console.log
const gnfdChainId = 9000;
const bnbUpperLimit = unit.mul(2000_000)
const initConsensusState: ConsensusState = require('./data/consensus-state-testnet.json')

const main = async () => {
  await deployGreenFieldContracts(gnfdChainId, bnbUpperLimit, initConsensusState)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
