import { Deployer } from '../typechain-types';
import { sleep, toHuman } from './helper';

const fs = require('fs');
const { execSync } = require('child_process');
const { ethers } = require('hardhat');

const log = console.log;
const unit = ethers.constants.WeiPerEther;

const gnfdChainId = 7971;
const initConsensusState: any = {
    chainID: 'greenfield_7971-1',
    height: 1,
    nextValidatorSetHash: '0x38e0755cf22d1b461042267e1becf974aa95499c6dd01fe657ab7cba056576ee',
    validators: [
        {
            pubKey: '0x9656f518c3169bb921e49dde966d43cc0aebca5232d6cf85385f8ffad270d54b',
            votingPower: 1000,
            relayerAddress: '0x2edd53b48726a887c98adab97e0a8600f855570d',
            relayerBlsKey:
                '0xa22249e548ef1829660521d3ab4496ebee89781f2b91cc237b36caef014f6779ba82e5c784515a9e3702ad356f5bbee1',
        },
        {
            pubKey: '0xb3b66156ff2463eb82b74f60f6b2c7396dffa8727552af39b5ee5c32440b7963',
            votingPower: 1000,
            relayerAddress: '0x115e247d2771f08fdd94c16ac01381082ebc73d1',
            relayerBlsKey:
                '0x84ed5dc9551e8e44fce09dc30272156fd70a094cc5e9f1d69fabd04630d8961036b9497a563d1de9f7b98a7d2a178419',
        },
        {
            pubKey: '0x97328a8ace9a8722ec6f9232075425672bb5590b8a1a68a104fe072e30e52ff3',
            votingPower: 1000,
            relayerAddress: '0xa4a2957e858529ffabbbb483d1d704378a9fca6b',
            relayerBlsKey:
                '0xa5e140ee80a0ff1552a954701f599622adf029916f55b3157a649e16086a0669900f784d03bff79e69eb8eb7ccfd77d8',
        },
        {
            pubKey: '0x4629ce60903edab13f06cfadad4c6646e3a2435c85ad7cbdd1966805400174a0',
            votingPower: 1000,
            relayerAddress: '0x4038993e087832d84e2ac855d27f6b0b2eec1907',
            relayerBlsKey:
                '0xad10ab912fcf510dfca1d27ab8a3d2a8b197e09bd69cd0e80e960d653e656073e89d417cf6f22de627710ccab352e6c2',
        },
        {
            pubKey: '0xeba438da90262e1a66869d394498eaf79b9a3c8a2ed1fe902e63ae2ca9c32b54',
            votingPower: 1000,
            relayerAddress: '0x2bbe5c8e5c3eb2b35063b330749f1958206d2ec2',
            relayerBlsKey:
                '0x9762663048cd982ae30da530ed6d0262e8adaafe6da99c9133f8ae2182c5776f35cd8e6a722a3306aa43b543907fca68',
        },
    ],
    consensusStateBytes:
        '0x677265656e6669656c645f373937312d31000000000000000000000000000000000000000000000138e0755cf22d1b461042267e1becf974aa95499c6dd01fe657ab7cba056576ee9656f518c3169bb921e49dde966d43cc0aebca5232d6cf85385f8ffad270d54b00000000000003e82edd53b48726a887c98adab97e0a8600f855570da22249e548ef1829660521d3ab4496ebee89781f2b91cc237b36caef014f6779ba82e5c784515a9e3702ad356f5bbee1b3b66156ff2463eb82b74f60f6b2c7396dffa8727552af39b5ee5c32440b796300000000000003e8115e247d2771f08fdd94c16ac01381082ebc73d184ed5dc9551e8e44fce09dc30272156fd70a094cc5e9f1d69fabd04630d8961036b9497a563d1de9f7b98a7d2a17841997328a8ace9a8722ec6f9232075425672bb5590b8a1a68a104fe072e30e52ff300000000000003e8a4a2957e858529ffabbbb483d1d704378a9fca6ba5e140ee80a0ff1552a954701f599622adf029916f55b3157a649e16086a0669900f784d03bff79e69eb8eb7ccfd77d84629ce60903edab13f06cfadad4c6646e3a2435c85ad7cbdd1966805400174a000000000000003e84038993e087832d84e2ac855d27f6b0b2eec1907ad10ab912fcf510dfca1d27ab8a3d2a8b197e09bd69cd0e80e960d653e656073e89d417cf6f22de627710ccab352e6c2eba438da90262e1a66869d394498eaf79b9a3c8a2ed1fe902e63ae2ca9c32b5400000000000003e82bbe5c8e5c3eb2b35063b330749f1958206d2ec29762663048cd982ae30da530ed6d0262e8adaafe6da99c9133f8ae2182c5776f35cd8e6a722a3306aa43b543907fca68',
};

const initConsensusStateBytes = initConsensusState.consensusStateBytes;
const main = async () => {
    const [operator, operator2, faucet] = await ethers.getSigners();
    const balance = await ethers.provider.getBalance(operator.address);
    const network = await ethers.provider.getNetwork();
    log('network', network);
    log('operator.address: ', operator.address, toHuman(balance));

    if (balance.lt(unit)) {
        const tx = await faucet.sendTransaction({
            to: operator.address,
            value: unit.mul(50_000),
        });
        await tx.wait(2);
        log('after got bnb, operator.address: ', operator.address, toHuman(balance));
    }

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

    const bucketRlp = await deployContract('BucketRlp');
    log('deploy bucketRlp success', bucketRlp.address);

    const objectRlp = await deployContract('ObjectRlp');
    log('deploy objectRlp success', objectRlp.address);

    const groupRlp = await deployContract('GroupRlp');
    log('deploy groupRlp success', groupRlp.address);

    await groupRlp.deployTransaction.wait(5);

    let tx = await deployer.init([
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
        bucketRlp.address,
        objectRlp.address,
        groupRlp.address,
    ]);
    log('deployer init success');

    await tx.wait(5);

    tx = await deployer.deploy(initConsensusStateBytes);
    log('deploy success');

    await tx.wait(5);

    const deployment: any = {
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

    tx = await operator.sendTransaction({
        to: proxyTokenHub,
        value: unit.mul(10000),
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

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
