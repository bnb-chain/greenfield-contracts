import { BigNumber } from 'ethers';
import { Deployer } from '../typechain-types';

const fs = require('fs');
const { execSync } = require('child_process');
const { ethers } = require('hardhat');

const log = console.log;

const gnfdChainId = 1;
const initConsensusState: any = {
    chainID: 'greenfield_9000-121',
    height: 1,
    nextValidatorSetHash: '0xa08cee315201a7feb401ba9f312ec3027857b3580f15045f425f44b77bbfc81c',
    validators: [
        {
            pubKey: '0xb26884f23fb9b226f5f06f8d01018402b3798555359997fcbb9c08b062dcce98',
            votingPower: 10000,
            relayerAddress: '0x6e7eaeb9d235d5a0f38d6e3da558bd500f1dff34',
            relayerBlsKey:
                '0x92789ccca38e43af7040d367f0af050899bbff1114727593759082cc5ff0984089171077f714371877b16d28d56ffe9d',
        },
        {
            pubKey: '0x42963ecb1e1e4b3e6e2085fcf0d44eedad9c40c5f9b725b115c659cbf0e36d41',
            votingPower: 10000,
            relayerAddress: '0xb5ee9c977f4a1679af2025fd6a1fac7240c9d50d',
            relayerBlsKey:
                '0x8ea2f08235b9cf8b24a030401a1abd3d8df2d53b844acfd0f360de844fce39ccef6899c438f03abf053eca45fde7111b',
        },
        {
            pubKey: '0x53eadb1084705ef2c90f2a52e46819e8a22937f1cc80f12d7163c8b47c11271f',
            votingPower: 10000,
            relayerAddress: '0xe732055240643ae92a3668295d398c7ddd2da810',
            relayerBlsKey:
                '0x98a287cb5d67437db9e7559541142e01cc03d5a1866d7d504e522b2fbdcb29d755c1d18c55949b309f2584f0c49c0dcc',
        },
    ],
    consensusStateBytes:
        '0x677265656e6669656c645f393030302d313231000000000000000000000000000000000000000001a08cee315201a7feb401ba9f312ec3027857b3580f15045f425f44b77bbfc81cb26884f23fb9b226f5f06f8d01018402b3798555359997fcbb9c08b062dcce9800000000000027106e7eaeb9d235d5a0f38d6e3da558bd500f1dff3492789ccca38e43af7040d367f0af050899bbff1114727593759082cc5ff0984089171077f714371877b16d28d56ffe9d42963ecb1e1e4b3e6e2085fcf0d44eedad9c40c5f9b725b115c659cbf0e36d410000000000002710b5ee9c977f4a1679af2025fd6a1fac7240c9d50d8ea2f08235b9cf8b24a030401a1abd3d8df2d53b844acfd0f360de844fce39ccef6899c438f03abf053eca45fde7111b53eadb1084705ef2c90f2a52e46819e8a22937f1cc80f12d7163c8b47c11271f0000000000002710e732055240643ae92a3668295d398c7ddd2da81098a287cb5d67437db9e7559541142e01cc03d5a1866d7d504e522b2fbdcb29d755c1d18c55949b309f2584f0c49c0dcc',
};

const initConsensusStateBytes = initConsensusState.consensusStateBytes;
const main = async () => {
    const [operator] = await ethers.getSigners();
    const balance = await ethers.provider.getBalance(operator.address);
    const network = await ethers.provider.getNetwork();
    log('network', network);
    log('operator.address: ', operator.address, toHuman(balance));
    const deployer = (await deployContract('Deployer', gnfdChainId)) as Deployer;

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
        initConsensusStateBytes,
        implGovHub.address,
        implCrossChain.address,
        implTokenHub.address,
        implLightClient.address,
        implRelayerHub.address
    );

    log('deployer.deploy() success', deployer.address);

    await tx.wait(1);

    const deployment: any = {
        Deployer: deployer.address,

        ProxyAdmin: proxyAdmin,
        GovHub: proxyGovHub,
        CrossChain: proxyCrossChain,
        TokenHub: proxyTokenHub,
        LightClient: proxyLightClient,
        RelayerHub: proxyRelayerHub,

        initConsensusState,
        gnfdChainId
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
};

async function sleep(seconds: number) {
    return new Promise((resolve) => setTimeout(resolve, seconds * 1000));
}

export const toHuman = (x: BigNumber, decimals?: number) => {
    if (!decimals) decimals = 18;
    return ethers.utils.formatUnits(x, decimals);
};

const deployContract = async (factoryPath: string, ...args: any) => {
    const factory = await ethers.getContractFactory(factoryPath);
    const contract = await factory.deploy(...args);
    await contract.deployTransaction.wait(1);
    return contract;
};

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
