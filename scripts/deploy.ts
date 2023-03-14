import { BigNumber } from 'ethers';
import { Deployer } from '../typechain-types';

const fs = require('fs');
const { execSync } = require('child_process');
const { ethers } = require('hardhat');

const log = console.log;

const gnfdChainId = 18;
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
        '0x677265656e6669656c645f393030302d3132310000000000000000000000000000000000000000010b57a425ca57932586438c78abd68b5239f1a96f9fcf1f19b07071f70df5df35792f80b491e93afb3b22ec443269fe756fce66f6cd41ba57f3a1c6a6816adb6f0000000000989680cf343afd1e924ebde9fbd1bca91d0fa685789e02a391f21d194db72fd6aa54c32a5d095f443e3499b4bec10a911344074669fff5bd56280d59062595e6dd85b5d86cc65452e15a978b10d60ce3d3adb4c63ee226df9e21c87d0c80f947af2279741f43c80000000000989680eca8b8b5329979910a58caa3aef322900b7e78a8b67f7fbb747b51678995201b9fea956048b2d7413c4ea299f6d9d39be6acd431de340bf238cdf47a78664a6aafc26e86af416e0aeaa3145ba64fbc54e8ab304c535f1912cea622b7299c9a40dcb102d700000000009896808b366d785228f2d7aab8c358ee6cc57a38686503aef7a4150c220f02de641f869cc61026818fbc4c1bfaabe6b4ba965694cf8eeaac48ed728958e0bf64e2d663fd68796e',
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

    await implRelayerHub.deployTransaction.wait(5)

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
