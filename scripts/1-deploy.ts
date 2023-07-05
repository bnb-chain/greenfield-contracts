import { Deployer } from '../typechain-types';
import { sleep, toHuman } from './helper';

const fs = require('fs');
const { execSync } = require('child_process');
const { ethers } = require('hardhat');

const log = console.log;
const unit = ethers.constants.WeiPerEther;

const gnfdChainId = 9000;
const initConsensusState: any = {
    chainID: 'greenfield_9000-1741',
    height: 1,
    nextValidatorSetHash: '0xaf6b801dda578dddfa4da1d5d67fd1b32510db24ec271346fc573e9242b01c9a',
  "validators": [
    {
      "pubKey": "0x112b51dda2d336246bdc0cc51407ba0cb0e5087be0db5f1cdc3285bbaa8e6475",
      "votingPower": 1000,
      "relayerAddress": "0x4202722cf6a34d727be762b46825b0d26b6263a0",
      "relayerBlsKey": "0xa9355ebf3c24bedac5a357a56feeb2cd8b6fed9f14cca15c3091f523b9fb21183b4bb31eb482a0321885e3f570721564"
    },
    {
      "pubKey": "0x48e2b2f7d9a3e7b668757d9cc0bbd28cd674c34ed1c2ed75c5de3b6a8f8cad46",
      "votingPower": 1000,
      "relayerAddress": "0x668a0acd8f6db5cae959a0e02132f4d6a672c4d7",
      "relayerBlsKey": "0xa4726b542012cc8023ee07b29ab3971cc999d8751bbd16f23413968afcdb070ed66ab47e6e1842bf875bef21dfc5b8af"
    },
    {
      "pubKey": "0x6813bfd82860d361e339bd1ae2f801b6d6ee46b8497a3d51c80b50b6160ea1cc",
      "votingPower": 1000,
      "relayerAddress": "0x0dfa99423d3084c596c5e3bd6bcb4f654516517b",
      "relayerBlsKey": "0x8d4786703c56b300b70f085c0d0482e5d6a3c7208883f0ec8abd2de893f71d18e8f919e7ab198499201d87f92c57ebce"
    },
    {
      "pubKey": "0x83ed2b763bb872e9bc148fb216fd5c93b18819670d9a946ae4b3075672d726b8",
      "votingPower": 1000,
      "relayerAddress": "0x24aab6f85470ff73e3048c64083a09e980d4cb7f",
      "relayerBlsKey": "0x8146d231a7b2051c5f7a9c07ab6e6bfe277bd5f4a94f901fe6ee7a6b6bd8479e9e5e448de4b1b33d5ddd74194c86b385"
    },
    {
      "pubKey": "0x2cc140a3f08a9c4149efd45643202f8bef2ad7eecf53e58951c6df6fd932004b",
      "votingPower": 1000,
      "relayerAddress": "0x4998f6ef8d999a0f36a851bfa29dbcf0364dd656",
      "relayerBlsKey": "0x95c286deb3f1657664859d59876bf1ec5a288f6e66e18b37b8a2a1e6ee4a3ef8fa50784d8b758d0c3e70a7cdfe65ab5d"
    }
  ],
    consensusStateBytes:
        '0x677265656e6669656c645f393030302d313734310000000000000000000000000000000000000001af6b801dda578dddfa4da1d5d67fd1b32510db24ec271346fc573e9242b01c9a112b51dda2d336246bdc0cc51407ba0cb0e5087be0db5f1cdc3285bbaa8e647500000000000003e84202722cf6a34d727be762b46825b0d26b6263a0a9355ebf3c24bedac5a357a56feeb2cd8b6fed9f14cca15c3091f523b9fb21183b4bb31eb482a0321885e3f57072156448e2b2f7d9a3e7b668757d9cc0bbd28cd674c34ed1c2ed75c5de3b6a8f8cad4600000000000003e8668a0acd8f6db5cae959a0e02132f4d6a672c4d7a4726b542012cc8023ee07b29ab3971cc999d8751bbd16f23413968afcdb070ed66ab47e6e1842bf875bef21dfc5b8af6813bfd82860d361e339bd1ae2f801b6d6ee46b8497a3d51c80b50b6160ea1cc00000000000003e80dfa99423d3084c596c5e3bd6bcb4f654516517b8d4786703c56b300b70f085c0d0482e5d6a3c7208883f0ec8abd2de893f71d18e8f919e7ab198499201d87f92c57ebce83ed2b763bb872e9bc148fb216fd5c93b18819670d9a946ae4b3075672d726b800000000000003e824aab6f85470ff73e3048c64083a09e980d4cb7f8146d231a7b2051c5f7a9c07ab6e6bfe277bd5f4a94f901fe6ee7a6b6bd8479e9e5e448de4b1b33d5ddd74194c86b3852cc140a3f08a9c4149efd45643202f8bef2ad7eecf53e58951c6df6fd932004b00000000000003e84998f6ef8d999a0f36a851bfa29dbcf0364dd65695c286deb3f1657664859d59876bf1ec5a288f6e66e18b37b8a2a1e6ee4a3ef8fa50784d8b758d0c3e70a7cdfe65ab5d',
};

const initConsensusStateBytes = initConsensusState.consensusStateBytes;
const main = async () => {
    const commitId = await getCommitId();
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
    const proxyBucketHub = await deployer.proxyBucketHub();
    const proxyObjectHub = await deployer.proxyObjectHub();
    const proxyGroupHub = await deployer.proxyGroupHub();

    const config: string = fs
        .readFileSync(__dirname + '/../contracts/Config.sol', 'utf8')
        .toString();
    const newConfig: string = config
        .replace(/PROXY_ADMIN = .*/g, `PROXY_ADMIN = ${proxyAdmin};`)
        .replace(/GOV_HUB = .*/g, `GOV_HUB = ${proxyGovHub};`)
        .replace(/CROSS_CHAIN = .*/g, `CROSS_CHAIN = ${proxyCrossChain};`)
        .replace(/TOKEN_HUB = .*/g, `TOKEN_HUB = ${proxyTokenHub};`)
        .replace(/LIGHT_CLIENT = .*/g, `LIGHT_CLIENT = ${proxyLightClient};`)
        .replace(/RELAYER_HUB = .*/g, `RELAYER_HUB = ${proxyRelayerHub};`)
        .replace(/BUCKET_HUB = .*/g, `BUCKET_HUB = ${proxyBucketHub};`)
        .replace(/OBJECT_HUB = .*/g, `OBJECT_HUB = ${proxyObjectHub};`)
        .replace(/GROUP_HUB = .*/g, `GROUP_HUB = ${proxyGroupHub};`);

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

    const implBucketHub = await deployContract('BucketHub');
    log('deploy implBucketHub success', implBucketHub.address);

    const implObjectHub = await deployContract('ObjectHub');
    log('deploy implObjectHub success', implObjectHub.address);

    const implGroupHub = await deployContract('GroupHub');
    log('deploy implGroupHub success', implGroupHub.address);

    const addBucketHub = await deployContract('AdditionalBucketHub');
    log('deploy addBucketHub success', addBucketHub.address);

    const addObjectHub = await deployContract('AdditionalObjectHub');
    log('deploy addObjectHub success', addObjectHub.address);

    const addGroupHub = await deployContract('AdditionalGroupHub');
    log('deploy addGroupHub success', addGroupHub.address);

    const bucketToken = await deployContract(
        'ERC721NonTransferable',
        'GreenField-Bucket',
        'BUCKET',
        'bucket',
        proxyBucketHub
    );
    log('deploy bucket token success', bucketToken.address);

    const objectToken = await deployContract(
        'ERC721NonTransferable',
        'GreenField-Object',
        'OBJECT',
        'object',
        proxyObjectHub
    );
    log('deploy object token success', objectToken.address);

    const groupToken = await deployContract(
        'ERC721NonTransferable',
        'GreenField-Group',
        'GROUP',
        'group',
        proxyGroupHub
    );
    log('deploy group token success', groupToken.address);

    const memberToken = await deployContract('ERC1155NonTransferable', 'member', proxyGroupHub);
    log('deploy member token success', memberToken.address);

    const initAddrs = [
        implGovHub.address,
        implCrossChain.address,
        implTokenHub.address,
        implLightClient.address,
        implRelayerHub.address,
        implBucketHub.address,
        implObjectHub.address,
        implGroupHub.address,
        addBucketHub.address,
        addObjectHub.address,
        addGroupHub.address,
        bucketToken.address,
        objectToken.address,
        groupToken.address,
        memberToken.address,
    ];

    let tx = await deployer.deploy(initAddrs, initConsensusStateBytes);
    await tx.wait(5);
    log('deploy success');

    const blockNumber = await ethers.provider.getBlockNumber()
    const deployment: any = {
        RepoCommitId: commitId,
        BlockNumber: blockNumber,

        Deployer: deployer.address,

        ProxyAdmin: proxyAdmin,
        GovHub: proxyGovHub,
        CrossChain: proxyCrossChain,
        TokenHub: proxyTokenHub,
        LightClient: proxyLightClient,
        RelayerHub: proxyRelayerHub,
        BucketHub: proxyBucketHub,
        ObjectHub: proxyObjectHub,
        GroupHub: proxyGroupHub,
        AdditionalBucketHub: addBucketHub.address,
        AdditionalObjectHub: addObjectHub.address,
        AdditionalGroupHub: addGroupHub.address,

        initConsensusState,
        gnfdChainId,
    };
    log('all contracts', JSON.stringify(deployment, null, 2));

    const deploymentDir = __dirname + `/../deployment`;
    if (!fs.existsSync(deploymentDir)) {
        fs.mkdirSync(deploymentDir, { recursive: true });
    }
    fs.writeFileSync(
        `${deploymentDir}/${network.chainId}-deployment.json`,
        JSON.stringify(deployment, null, 2)
    );

    // BSC Mainnet
    if (network.chainId === 56) {
        return;
    }

    tx = await operator.sendTransaction({
        to: proxyTokenHub,
        value: unit.mul(1000),
    });
    await tx.wait(1);
    log('balance of TokenHub', await ethers.provider.getBalance(proxyTokenHub));

    const validators = initConsensusState.validators;
    for (let i = 0; i < validators.length; i++) {
        const relayer = validators[i].relayerAddress;
        tx = await operator.sendTransaction({
            to: ethers.utils.getAddress(relayer),
            value: unit.mul(100),
        });
        await tx.wait(1);
    }
    log('transfer bnb to validators');
};

const deployContract = async (factoryPath: string, ...args: any) => {
    const factory = await ethers.getContractFactory(factoryPath);
    const contract = await factory.deploy(...args);
    await contract.deployTransaction.wait(1);
    return contract;
};

const getCommitId = async (): Promise<string> => {
    try {
        const result = execSync('git rev-parse HEAD');
        log('getCommitId', result.toString().trim());
        return result.toString().trim();
    } catch (e) {
        console.error('getCommitId error', e);
        return '';
    }
};

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
