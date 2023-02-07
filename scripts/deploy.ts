import {BigNumber} from "ethers";
import {Deployer} from "../typechain-types";

const fs = require('fs')
const {execSync} = require("child_process");
const { ethers } = require('hardhat');

const log = console.log

const gnfdChainId = 2

const main = async () => {
    const [operator] = await ethers.getSigners()
    const balance = await ethers.provider.getBalance(operator.address);
    const network = await ethers.provider.getNetwork()
    log('network', network)
    log('operator.address: ', operator.address, toHuman(balance));
    const deployer = (await deployContract('Deployer', gnfdChainId)) as Deployer
    
    log('Deployer deployed', deployer.address)

    const proxyAdmin = await deployer.proxyAdmin()
    const proxyGovHub = await deployer.proxyGovHub()
    const proxyCrossChain = await deployer.proxyCrossChain()
    const proxyTokenHub = await deployer.proxyTokenHub()
    const proxyLightClient = await deployer.proxyLightClient()
    const proxyRelayerHub = await deployer.proxyRelayerHub()

    const config: string = fs.readFileSync(__dirname + '/../contracts/Config.sol', "utf8").toString()
    const newConfig: string =
        config
            .replace(/PROXY_ADMIN = .*/g, `PROXY_ADMIN = ${proxyAdmin};`)
            .replace(/GOV_HUB = .*/g, `GOV_HUB = ${proxyGovHub};`)
            .replace(/CROSS_CHAIN = .*/g, `CROSS_CHAIN = ${proxyCrossChain};`)
            .replace(/TOKEN_HUB = .*/g, `TOKEN_HUB = ${proxyTokenHub};`)
            .replace(/LIGHT_CLIENT = .*/g, `LIGHT_CLIENT = ${proxyLightClient};`)
            .replace(/RELAYER_HUB = .*/g, `RELAYER_HUB = ${proxyRelayerHub};`)

    log("Set all generated contracts to Config contracts")

    fs.writeFileSync(__dirname + '/../contracts/Config.sol', newConfig, "utf8")
    await sleep(2)
    execSync("npx hardhat compile")
    await sleep(2)

    const init_cs_bytes = '0x677265656e6669656c645f393030302d313231000000000000000000000000000000000000000001a5f1af4874227f1cdbe5240259a365ad86484a4255bfd65e2a0222d733fcdbc320cc466ee9412ddd49e0fff04cdb41bade2b7622f08b6bdacac94d4de03bdb970000000000002710d5e63aeee6e6fa122a6a23a6e0fca87701ba1541aa2d28cbcd1ea3a63479f6fb260a3d755853e6a78cfa6252584fee97b2ec84a9d572ee4a5d3bc1558bb98a4b370fb8616b0b523ee91ad18a63d63f21e0c40a83ef15963f4260574ca5159fd90a1c527000000000000027106fd1ceb5a48579f322605220d4325bd9ff90d5fab31e74a881fc78681e3dfa440978d2b8be0708a1cbbca2c660866216975fdaf0e9038d9b7ccbf9731f43956dba7f2451919606ae20bf5d248ee353821754bcdb456fd3950618fda3e32d3d0fb990eeda000000000000271097376a436bbf54e0f6949b57aa821a90a749920ab32979580ea04984a2be033599c20c7a0c9a8d121b57f94ee05f5eda5b36c38f6e354c89328b92cdd1de33b64d3a0867'
    const implGovHub = await deployContract('GovHub')
    log('deploy implGovHub success', implGovHub.address)

    const implCrossChain = await deployContract('CrossChain');
    log('deploy implCrossChain success', implCrossChain.address)

    const implTokenHub = await deployContract('TokenHub');
    log('deploy implTokenHub success', implTokenHub.address)

    const implLightClient = await deployContract('GnfdLightClient');
    log('deploy implLightClient success', implLightClient.address)

    const implRelayerHub = await deployContract('RelayerHub');
    log('deploy implRelayerHub success', implRelayerHub.address)

    const tx = await deployer.deploy(
        init_cs_bytes,
        implGovHub.address,
        implCrossChain.address,
        implTokenHub.address,
        implLightClient.address,
        implRelayerHub.address,
    );

    log('deployer.deploy() success', deployer.address)

    await tx.wait(1)

    const deployedContracts: any = {
        'Deployer': deployer.address,

        'ProxyAdmin': proxyAdmin,
        'GovHub': proxyGovHub,
        'CrossChain': proxyCrossChain,
        'TokenHub': proxyTokenHub,
        'LightClient': proxyLightClient,
        'RelayerHub': proxyRelayerHub,
    }
    log('all contracts', deployedContracts)

    fs.writeFileSync(
        __dirname + `/../deployed/${ network.chainId }-GreenField-contracts.json`,
        JSON.stringify(deployedContracts, null, 2)
    )
}

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
