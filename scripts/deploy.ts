import { BigNumber } from 'ethers';
import { Deployer } from '../typechain-types';

const fs = require('fs');
const { execSync } = require('child_process');
const { ethers } = require('hardhat');

const log = console.log;

const gnfdChainId = 9000;
const initConsensusState: any = {
    chainID: 'greenfield_9000-1741',
    height: 1,
    nextValidatorSetHash: '0xa08cee315201a7feb401ba9f312ec3027857b3580f15045f425f44b77bbfc81c',
    validators: [
        {
            pubKey: '0xb26884f23fb9b226f5f06f8d01018402b3798555359997fcbb9c08b062dcce98',
            votingPower: 10000,
            relayerAddress: '0x2edd53b48726a887c98adab97e0a8600f855570d',
            relayerBlsKey:
                '0x92789ccca38e43af7040d367f0af050899bbff1114727593759082cc5ff0984089171077f714371877b16d28d56ffe9d',
        },
        {
            pubKey: '0x42963ecb1e1e4b3e6e2085fcf0d44eedad9c40c5f9b725b115c659cbf0e36d41',
            votingPower: 10000,
            relayerAddress: '0x115e247d2771f08fdd94c16ac01381082ebc73d1',
            relayerBlsKey:
                '0x8ea2f08235b9cf8b24a030401a1abd3d8df2d53b844acfd0f360de844fce39ccef6899c438f03abf053eca45fde7111b',
        },
        {
            pubKey: '0x53eadb1084705ef2c90f2a52e46819e8a22937f1cc80f12d7163c8b47c11271f',
            votingPower: 10000,
            relayerAddress: '0xa4a2957e858529ffabbbb483d1d704378a9fca6b',
            relayerBlsKey:
                '0x98a287cb5d67437db9e7559541142e01cc03d5a1866d7d504e522b2fbdcb29d755c1d18c55949b309f2584f0c49c0dcc',
        },
    ],
    consensusStateBytes:
        '0x677265656e6669656c645f393030302d313734310000000000000000000000000000000000000001f4bd37f0ba6203ea223707b01fd45c537abe4fb3dea7df7a28b6bca90d42d7a0abdf77404f8333e67be33125641303cfc526d7c153bb83f45d0705a62abfb7bc0000000000002710f2e5ef61c10466095b7de9cf86c00df6a46aec358ef473d5c8eaf6e5aad5cfe9ac9eb6e1b6d7085cf7bd47bf401e29a33129e7c80889f5ce14fd65905408bd18a6ec8e13c28950fb9cae9456b5206857bb79e3385567fc2654b03a3234ce001a33a92dfa00000000000027107239b73ca99b095d4fee1495cb62e36be8cfeed1943812df64c11b13ab495307deac3d588c01c87dd9368e2209d72569b874772b3286af2175d7dcfb4776202e2ebc2ea83a87613e4f926a704b2cc6ed353134995f572e3116d3a6128d6d0df5a32959a00000000000002710b5c1df809f9c00a51ca3d97b5071cf2945ce7f32872cfdc255a50dd401029d2c94d7eeef0eadb2f9336a9e6117d9abb6b0fba83808bc60d1cf1e11cf4dce67b8811da860fd40d0076fa181a110ab8f5da13cdcb42474640e22dfd90932aa55fdb99abfc10000000000002710356a04cc2dbd0b55040cad4a0358530a0aa8f440b31bcccf8e15c4e9a1a310f138fa97c3416d878a16c1c09c792e1d195a5641a6c8e7783693e8fe46078d92b5134642097862bc7143514bc8bd62d574bc304b1a51625dd205d875baff921f9332c7bc3900000000000027106bbcca3ca63fbcbb1cfe7cad53ef865ae3684335a1d7612bae74f65874403726edc9501e45fc345ef05b0fc974fc044a331ed1dec66a1a044d96f4cfb630d7ce57fb9bac',
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
