import { Deployer } from '../typechain-types';
import { sleep, toHuman } from './helper';

const fs = require('fs');
const { execSync } = require('child_process');
const { ethers } = require('hardhat');

const log = console.log;
const unit = ethers.constants.WeiPerEther;

// @dev Caution: crosschain transfer not allowed on opbnb
let enableCrossChainTransfer = false;
// TODO
const gnfdChainId = 1017;
// TODO
let emergencyOperator = ''; // suspend / reopen / cancelTransfer
// TODO
let emergencyUpgradeOperator = ''; // update params / upgrade contracts
// TODO modify consensusStateBytes
const initConsensusState: any = {
    chainID: 'greenfield_1017-1',
    height: 1806202,
    nextValidatorSetHash: "0x1934cd5af1b1a6ec756032f07411f2452ccaea94d1bbeb5001484ca70d16e1d2",
    validators: [
        {
            pubKey: '0xe139c29f889cce200de9e073b242c7c240e9b45f1ba92be8ca815b8345f17f16',
            votingPower: 1000,
            relayerAddress: '0xe144b8627860d3415e413270f02707ca632dc443',
            relayerBlsKey:
                '0xa932ac99412f035226dc0748f324364dac615d8022dcde79b8e4b5413e9555e0b3e6d09916f41d0c77a9760c9f786e36',
        },

        {
            pubKey: '0x9b4f7216e31e16ccd653bb78491611307f82d36a75cd725be5ac65eaf980ffa4',
            votingPower: 1000,
            relayerAddress: '0x23e774ae66a074f49245c4e9c76e6ea24bae431b',
            relayerBlsKey:
                '0x974232a15058c5d2ac1a45bef2e67b21c55d6213bd6d80fdb9542a9f96c2cbc96e2852eb5fecbca13b4220a7fee4e269',
        },

        {
            pubKey: '0x4d5ee37c2b16b5cf24a1cc48e89103d29f204a09173e9ddc87842fd01aea69c7',
            votingPower: 1000,
            relayerAddress: '0xa800cd1039cef2817913f8b6a6ae5aeeb94f7291',
            relayerBlsKey:
                '0xb5d44f5f9b764bee50d650785f34ef1698eec336f9a6b3697a073feb7549bacc69c02a5bba55dfab1b7d71da1611dccf',
        },

        {
            pubKey: '0x1c0177943226d42a9aadd11b14f23eac082359d58541871ca01a17b9d8a0a99a',
            votingPower: 1000,
            relayerAddress: '0xea7fd841924588a0951e77cda1ea73c73dec0b01',
            relayerBlsKey:
                '0x96a8efc434e063e6362f333c6134d680bb618790a88ba86e9d2a1aff1495c1af71faf46d3091d1387754a487c7f9b1bc',
        },

        {
            pubKey: '0x4d53e2e86ba7ed4900c05e05e909247fe0f90316c521cca410ac010b440c5496',
            votingPower: 1000,
            relayerAddress: '0x0c62ba9819e426fbe1c2d3dddf2d504eef78bfeb',
            relayerBlsKey:
                '0x956707b850920b24867e9c9a97c972addcb6bae02493b022b65098fb54b7fbeea40b3812bd9a0c8e9e25d18aed2362e3',
        },

        {
            pubKey: '0xb8af4a2db9baf7f9e219a370d535f211677d4d7fee75c88bd51ec1e69fd50fac',
            votingPower: 1000,
            relayerAddress: '0xc36db5f165b6870cf6dd1a3569f9f17ed83a27e5',
            relayerBlsKey:
                '0x8d0e78ffda6c0d9d9265f338ffa1550aa57c43aeca8271d298c8a70f5d05ccc4a78205f096b1192ff65601afb06d28c3',
        },

        {
            pubKey: '0x85c5eb97bc1802c9ba0c70ce2ab4f95187aa70f79c5b35ff62c2d877efe6297f',
            votingPower: 1000,
            relayerAddress: '0x14cfe3777565d942f7a3e1d1dcffd7945170c8fe',
            relayerBlsKey:
                '0xa2deebd6b62fae2ad4612820af8f26749c7ce066ea4d2b981d8eb83653387ff1ad551bf3646618493550a6c6ddabdf22',
        },

        {
            pubKey: '0x1c2349fae25b51493d91817fe1604628030255ea77b315a124a219cdfc85649d',
            votingPower: 1000,
            relayerAddress: '0x8ccf50a90a9a917709bc800e627dc34924aef9a2',
            relayerBlsKey:
                '0xb677f77501e4ff86acf32c1f6c1172db15411b1fd05a76058ce13ddb02af06e8c75cf2b1d3c69bcb0af8d2946451eca9',
        },

        {
            pubKey: '0x0ddeb663611c837df54a2fed6ebdc492aa201589f9eeda732db190d4a722caae',
            votingPower: 1000,
            relayerAddress: '0x7af04d428544044896d99a70fa18354f89bd63b6',
            relayerBlsKey:
                '0xb53daaea46897da5cf8c628291719283eadfc32fae5d167b755b10e911b97f98669ec434a8de3ce77ef4e9bdebf6db49',
        },

        {
            pubKey: '0xdb281040d6b6c8099d73a2ed4fd6a71425a8bda7687b474f2b8f59c4ac67ff23',
            votingPower: 1000,
            relayerAddress: '0x4d576649d6caab609fdca92df4f93e6b34ce616e',
            relayerBlsKey:
                '0x96dcb603d11b349e39a600cee95233ce06886c4d1275f58becca79bf78760f33651c08912ce4bfe2bc19008103c3b5d5',
        },

        {
            pubKey: '0xacb5a8f4c2a3a87405124c86470e6bf0428da0d6a18e026bb81a01491abefc41',
            votingPower: 1000,
            relayerAddress: '0x406b23e5b9cb00423db2b636bfa51b1cce1e482e',
            relayerBlsKey:
                '0xa20d2705cf85329fd67888e4dbfd92ae26b7d241e82524f0fc932f7d0621809302a05e1aad4e3207b6567e8b48e984b8',
        },

        {
            pubKey: '0x4ec641128323e41b9d031775c65fc16cfb1e675e8adc5355bf349e44665bc211',
            votingPower: 1000,
            relayerAddress: '0x93b251c895f133ceb28696acfba0e1f4d5ffbcb2',
            relayerBlsKey:
                '0x8916d9c8addca8d632ac020cb078d1a0b0f1be57bad177a343f0335f22555fc93057db3c1b9c122e4511954f8c79f73f',
        },

        {
            pubKey: '0x8c03165d37ede71e25f7736c9845c4402ba0792c0c439c960f7b716f4b723c9d',
            votingPower: 1000,
            relayerAddress: '0x12d720c8241c209079ef1ba820aaed097f67a427',
            relayerBlsKey:
                '0xac74ddfca0315712f596f800f3ab66c6bfbe925ca6664f5a26d3b3f58772bfd34f0d8c518c9788b1f563bcbb7caa7362',
        },

    ],
    consensusStateBytes:
        '0x677265656e6669656c645f313031372d3100000000000000000000000000000000000000001b8f7a1934cd5af1b1a6ec756032f07411f2452ccaea94d1bbeb5001484ca70d16e1d2e139c29f889cce200de9e073b242c7c240e9b45f1ba92be8ca815b8345f17f1600000000000003e8e144b8627860d3415e413270f02707ca632dc443a932ac99412f035226dc0748f324364dac615d8022dcde79b8e4b5413e9555e0b3e6d09916f41d0c77a9760c9f786e369b4f7216e31e16ccd653bb78491611307f82d36a75cd725be5ac65eaf980ffa400000000000003e823e774ae66a074f49245c4e9c76e6ea24bae431b974232a15058c5d2ac1a45bef2e67b21c55d6213bd6d80fdb9542a9f96c2cbc96e2852eb5fecbca13b4220a7fee4e2694d5ee37c2b16b5cf24a1cc48e89103d29f204a09173e9ddc87842fd01aea69c700000000000003e8a800cd1039cef2817913f8b6a6ae5aeeb94f7291b5d44f5f9b764bee50d650785f34ef1698eec336f9a6b3697a073feb7549bacc69c02a5bba55dfab1b7d71da1611dccf1c0177943226d42a9aadd11b14f23eac082359d58541871ca01a17b9d8a0a99a00000000000003e8ea7fd841924588a0951e77cda1ea73c73dec0b0196a8efc434e063e6362f333c6134d680bb618790a88ba86e9d2a1aff1495c1af71faf46d3091d1387754a487c7f9b1bc4d53e2e86ba7ed4900c05e05e909247fe0f90316c521cca410ac010b440c549600000000000003e80c62ba9819e426fbe1c2d3dddf2d504eef78bfeb956707b850920b24867e9c9a97c972addcb6bae02493b022b65098fb54b7fbeea40b3812bd9a0c8e9e25d18aed2362e3b8af4a2db9baf7f9e219a370d535f211677d4d7fee75c88bd51ec1e69fd50fac00000000000003e8c36db5f165b6870cf6dd1a3569f9f17ed83a27e58d0e78ffda6c0d9d9265f338ffa1550aa57c43aeca8271d298c8a70f5d05ccc4a78205f096b1192ff65601afb06d28c385c5eb97bc1802c9ba0c70ce2ab4f95187aa70f79c5b35ff62c2d877efe6297f00000000000003e814cfe3777565d942f7a3e1d1dcffd7945170c8fea2deebd6b62fae2ad4612820af8f26749c7ce066ea4d2b981d8eb83653387ff1ad551bf3646618493550a6c6ddabdf221c2349fae25b51493d91817fe1604628030255ea77b315a124a219cdfc85649d00000000000003e88ccf50a90a9a917709bc800e627dc34924aef9a2b677f77501e4ff86acf32c1f6c1172db15411b1fd05a76058ce13ddb02af06e8c75cf2b1d3c69bcb0af8d2946451eca90ddeb663611c837df54a2fed6ebdc492aa201589f9eeda732db190d4a722caae00000000000003e87af04d428544044896d99a70fa18354f89bd63b6b53daaea46897da5cf8c628291719283eadfc32fae5d167b755b10e911b97f98669ec434a8de3ce77ef4e9bdebf6db49db281040d6b6c8099d73a2ed4fd6a71425a8bda7687b474f2b8f59c4ac67ff2300000000000003e84d576649d6caab609fdca92df4f93e6b34ce616e96dcb603d11b349e39a600cee95233ce06886c4d1275f58becca79bf78760f33651c08912ce4bfe2bc19008103c3b5d5acb5a8f4c2a3a87405124c86470e6bf0428da0d6a18e026bb81a01491abefc4100000000000003e8406b23e5b9cb00423db2b636bfa51b1cce1e482ea20d2705cf85329fd67888e4dbfd92ae26b7d241e82524f0fc932f7d0621809302a05e1aad4e3207b6567e8b48e984b84ec641128323e41b9d031775c65fc16cfb1e675e8adc5355bf349e44665bc21100000000000003e893b251c895f133ceb28696acfba0e1f4d5ffbcb28916d9c8addca8d632ac020cb078d1a0b0f1be57bad177a343f0335f22555fc93057db3c1b9c122e4511954f8c79f73f8c03165d37ede71e25f7736c9845c4402ba0792c0c439c960f7b716f4b723c9d00000000000003e812d720c8241c209079ef1ba820aaed097f67a427ac74ddfca0315712f596f800f3ab66c6bfbe925ca6664f5a26d3b3f58772bfd34f0d8c518c9788b1f563bcbb7caa7362',
}

const initConsensusStateBytes = initConsensusState.consensusStateBytes;
const main = async () => {
    const commitId = await getCommitId();
    const [operator] = await ethers.getSigners();
    const balance = await ethers.provider.getBalance(operator.address);
    const network = await ethers.provider.getNetwork();
    log('network', network);
    log('operator.address: ', operator.address, toHuman(balance));

    // OPBNB Mainnet
    if (network.chainId === 204) {
        if (!emergencyOperator) {
            throw new Error('emergencyOperator is not set');
        }

        if (!emergencyUpgradeOperator) {
            throw new Error('emergencyUpgradeOperator is not set');
        }

        let code = await ethers.provider.getCode(emergencyOperator);
        if (code.length < 10) {
            throw new Error('emergencyOperator is not multi-sig contract');
        }

        code = await ethers.provider.getCode(emergencyUpgradeOperator);
        if (code.length < 10) {
            throw new Error('emergencyUpgradeOperator is not multi-sig contract');
        }
    } else {
        // BSC Testnet
        if (!emergencyOperator) {
            emergencyOperator = operator.address;
        }

        if (!emergencyUpgradeOperator) {
            emergencyUpgradeOperator = operator.address;
        }
    }

    log('emergencyOperator: ', emergencyOperator);
    log('emergencyUpgradeOperator: ', emergencyUpgradeOperator);

    execSync('npx hardhat compile');
    await sleep(2);

    const deployer = (await deployContract(
        'Deployer',
        gnfdChainId,
        enableCrossChainTransfer
    )) as Deployer;
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
        .replace(/GROUP_HUB = .*/g, `GROUP_HUB = ${proxyGroupHub};`)
        .replace(/EMERGENCY_OPERATOR = .*/g, `EMERGENCY_OPERATOR = ${emergencyOperator};`)
        .replace(
            /EMERGENCY_UPGRADE_OPERATOR = .*/g,
            `EMERGENCY_UPGRADE_OPERATOR = ${emergencyUpgradeOperator};`
        );

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

    const blockNumber = await ethers.provider.getBlockNumber();
    const deployment: any = {
        DeployCommitId: commitId,
        BlockNumber: blockNumber,

        EmergencyOperator: emergencyOperator,
        EmergencyUpgradeOperator: emergencyUpgradeOperator,

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

        BucketERC721Token: bucketToken.address,
        ObjectERC721Token: objectToken.address,
        GroupERC721Token: groupToken.address,
        MemberERC1155Token: memberToken.address,

        initConsensusState,
        gnfdChainId,
        enableCrossChainTransfer,
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

    // opbnb Mainnet
    if (network.chainId === 204) {
        return;
    }

    tx = await operator.sendTransaction({
        to: proxyTokenHub,
        value: unit.mul(10),
    });
    await tx.wait(1);
    log('balance of TokenHub', await ethers.provider.getBalance(proxyTokenHub));

    const validators = initConsensusState.validators;
    for (let i = 0; i < validators.length; i++) {
        const relayer = validators[i].relayerAddress;
        tx = await operator.sendTransaction({
            to: ethers.utils.getAddress(relayer),
            value: unit.mul(5),
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
