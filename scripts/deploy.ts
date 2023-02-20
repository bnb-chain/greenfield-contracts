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
    nextValidatorSetHash: '0xD0BC020D397EB827B4FA8C167AB67CDB00CF1F02A64AFDA74F16C4DF3EEE2EEF',
    validators: [
        {
            pubKey: '9656f518c3169bb921e49dde966d43cc0aebca5232d6cf85385f8ffad270d54b',
            votingPower: 10000,
            relayerAddress: '2edd53b48726a887c98adab97e0a8600f855570d',
            relayerBlsKey:
                'a22249e548ef1829660521d3ab4496ebee89781f2b91cc237b36caef014f6779ba82e5c784515a9e3702ad356f5bbee1',
        },
        {
            pubKey: 'b3b66156ff2463eb82b74f60f6b2c7396dffa8727552af39b5ee5c32440b7963',
            votingPower: 10000,
            relayerAddress: '115e247d2771f08fdd94c16ac01381082ebc73d1',
            relayerBlsKey:
                '84ed5dc9551e8e44fce09dc30272156fd70a094cc5e9f1d69fabd04630d8961036b9497a563d1de9f7b98a7d2a178419',
        },
        {
            pubKey: '97328a8ace9a8722ec6f9232075425672bb5590b8a1a68a104fe072e30e52ff3',
            votingPower: 10000,
            relayerAddress: 'a4a2957e858529ffabbbb483d1d704378a9fca6b',
            relayerBlsKey:
                'a5e140ee80a0ff1552a954701f599622adf029916f55b3157a649e16086a0669900f784d03bff79e69eb8eb7ccfd77d8',
        },

        {
            pubKey: '4629ce60903edab13f06cfadad4c6646e3a2435c85ad7cbdd1966805400174a0',
            votingPower: 10000,
            relayerAddress: '4038993e087832d84e2ac855d27f6b0b2eec1907',
            relayerBlsKey:
                'ad10ab912fcf510dfca1d27ab8a3d2a8b197e09bd69cd0e80e960d653e656073e89d417cf6f22de627710ccab352e6c2',
        },
        {
            pubKey: 'eba438da90262e1a66869d394498eaf79b9a3c8a2ed1fe902e63ae2ca9c32b54',
            votingPower: 10000,
            relayerAddress: '2bbe5c8e5c3eb2b35063b330749f1958206d2ec2',
            relayerBlsKey:
                '9762663048cd982ae30da530ed6d0262e8adaafe6da99c9133f8ae2182c5776f35cd8e6a722a3306aa43b543907fca68',
        },
    ],
    consensusStateBytes:
        '0x677265656e6669656c645f393030302d313734310000000000000000000000000000000000000001b21e85227e42c4bb5afc6b08f958c844642ccdd164f305afa165fc3e5272485b9656f518c3169bb921e49dde966d43cc0aebca5232d6cf85385f8ffad270d54b00000000000027102edd53b48726a887c98adab97e0a8600f855570da22249e548ef1829660521d3ab4496ebee89781f2b91cc237b36caef014f6779ba82e5c784515a9e3702ad356f5bbee1b3b66156ff2463eb82b74f60f6b2c7396dffa8727552af39b5ee5c32440b79630000000000002710115e247d2771f08fdd94c16ac01381082ebc73d184ed5dc9551e8e44fce09dc30272156fd70a094cc5e9f1d69fabd04630d8961036b9497a563d1de9f7b98a7d2a17841997328a8ace9a8722ec6f9232075425672bb5590b8a1a68a104fe072e30e52ff30000000000002710a4a2957e858529ffabbbb483d1d704378a9fca6ba5e140ee80a0ff1552a954701f599622adf029916f55b3157a649e16086a0669900f784d03bff79e69eb8eb7ccfd77d84629ce60903edab13f06cfadad4c6646e3a2435c85ad7cbdd1966805400174a000000000000027104038993e087832d84e2ac855d27f6b0b2eec1907ad10ab912fcf510dfca1d27ab8a3d2a8b197e09bd69cd0e80e960d653e656073e89d417cf6f22de627710ccab352e6c2eba438da90262e1a66869d394498eaf79b9a3c8a2ed1fe902e63ae2ca9c32b5400000000000027102bbe5c8e5c3eb2b35063b330749f1958206d2ec29762663048cd982ae30da530ed6d0262e8adaafe6da99c9133f8ae2182c5776f35cd8e6a722a3306aa43b543907fca68',
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
