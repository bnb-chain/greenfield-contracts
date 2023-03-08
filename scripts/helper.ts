import { BigNumber } from 'ethers';
import { Deployer } from '../typechain-types';
const fs = require('fs');
const { execSync } = require('child_process');
const { ethers } = require('hardhat');
const log = console.log;

export const unit = ethers.constants.WeiPerEther

export interface Relayer {
  pubKey?: string,
  votingPower?: number,
  address: string,
  blsKey?: string,
}

export interface ConsensusState {
  gnfdChainId: number,
  bscChainId: number,
  gnfdHeight: number,
  nextValidatorSetHash: string,
  relayers: Relayer[],
  initConsensusStateBytes: string,
}

export interface Deployment {
    Deployer: string,

    ProxyAdmin: string,
    GovHub: string,
    CrossChain: string,
    TokenHub: string,
    LightClient: string,
    RelayerHub: string,

    initConsensusState: ConsensusState,
    gnfdChainId: number,
}

export const deployGreenFieldContracts =
    async (gnfdChainId: number, bnbUpperLimit: BigNumber, initConsensusState: ConsensusState): Deployment => {
  const [operator] = await ethers.getSigners();
  const balance = await ethers.provider.getBalance(operator.address);
  const network = await ethers.provider.getNetwork();
  log('network', network);
  log('operator.address: ', operator.address, toHuman(balance));
  const deployer = (await deployContract('Deployer', gnfdChainId, bnbUpperLimit)) as Deployer;

  log('Deployer deployed', deployer.address);

  const proxyAdmin = await deployer.proxyAdmin();
  const proxyGovHub = await deployer.proxyGovHub();
  const proxyCrossChain = await deployer.proxyCrossChain();
  const proxyTokenHub = await deployer.proxyTokenHub();
  const proxyLightClient = await deployer.proxyLightClient();
  const proxyRelayerHub = await deployer.proxyRelayerHub();

  const config: string = fs
    .readFileSync(__dirname + '/../contracts/Config.sol', 'utf8')
    .toString();
  const newConfig: string = config
    .replace(/PROXY_ADMIN = .*/g, `PROXY_ADMIN = ${proxyAdmin};`)
    .replace(/GOV_HUB = .*/g, `GOV_HUB = ${proxyGovHub};`)
    .replace(/CROSS_CHAIN = .*/g, `CROSS_CHAIN = ${proxyCrossChain};`)
    .replace(/TOKEN_HUB = .*/g, `TOKEN_HUB = ${proxyTokenHub};`)
    .replace(/LIGHT_CLIENT = .*/g, `LIGHT_CLIENT = ${proxyLightClient};`)
    .replace(/RELAYER_HUB = .*/g, `RELAYER_HUB = ${proxyRelayerHub};`);

  log('Set all generated contracts to Config contracts');

  fs.writeFileSync(__dirname + '/../contracts/Config.sol', newConfig, 'utf8');
  await sleep(2);
  execSync('npx hardhat compile');
  await sleep(2);

  const implGovHub = await deployContract('GovHub');
  log('deploy implGovHub success', implGovHub.address);

  const implCrossChain = await deployContract('CrossChain');
  log('deploy implCrossChain success', implCrossChain.address);

  const implTokenHub = await deployContract('TokenHub');
  log('deploy implTokenHub success', implTokenHub.address);

  const implLightClient = await deployContract('GnfdLightClient');
  log('deploy implLightClient success', implLightClient.address);

  const implRelayerHub = await deployContract('RelayerHub');
  log('deploy implRelayerHub success', implRelayerHub.address);

  const tx = await deployer.deploy(
    initConsensusState.initConsensusStateBytes,
    implGovHub.address,
    implCrossChain.address,
    implTokenHub.address,
    implLightClient.address,
    implRelayerHub.address
  );
  log('deployer.deploy() success', deployer.address);
  await tx.wait(1);

  const deployment: Deployment = {
    Deployer: deployer.address,

    ProxyAdmin: proxyAdmin,
    GovHub: proxyGovHub,
    CrossChain: proxyCrossChain,
    TokenHub: proxyTokenHub,
    LightClient: proxyLightClient,
    RelayerHub: proxyRelayerHub,

    initConsensusState,
    gnfdChainId,
  };
  log('all contracts', deployment);

  const deploymentDir = __dirname + `/../deployment`;
  if (!fs.existsSync(deploymentDir)) {
    fs.mkdirSync(deploymentDir, { recursive: true });
  }
  fs.writeFileSync(
    `${deploymentDir}/${network.chainId}-deployment.json`,
    JSON.stringify(deployment, null, 2)
  );

  return deployment
};

export async function sleep(seconds: number) {
  return new Promise((resolve) => setTimeout(resolve, seconds * 1000));
}

export const toHuman = (x: BigNumber, decimals?: number) => {
  if (!decimals) decimals = 18;
  return ethers.utils.formatUnits(x, decimals);
};

export const deployContract = async (factoryPath: string, ...args: any) => {
  const factory = await ethers.getContractFactory(factoryPath);
  const contract = await factory.deploy(...args);
  await contract.deployTransaction.wait(1);
  return contract;
};
