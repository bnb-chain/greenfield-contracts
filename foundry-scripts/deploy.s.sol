pragma solidity ^0.8.0;
import "forge-std/Script.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../contracts/InscriptionProxy.sol";
import "../contracts/InscriptionProxyAdmin.sol";
import "../contracts/InscriptionLightClient.sol";
import "../contracts/CrossChain.sol";
import "../contracts/middle-layer/GovHub.sol";
import "../contracts/middle-layer/TokenHub.sol";
import "../contracts/Deployer.sol";

contract DeployScript is Script {
    Deployer public deployer;

    function run(uint16 insChainId) public {
        uint256 privateKey = uint256(vm.envBytes32('PK1'));
        address developer = vm.addr(privateKey);

        vm.startBroadcast();

        deployer = new Deployer(insChainId);
        deployer.deploy();

        vm.stopBroadcast();

        address proxyGovHub = deployer.proxyGovHub();
        console.log('GovHub', proxyGovHub);
        console.log('proxyAdmin', GovHub(proxyGovHub).proxyAdmin());
        console.log('crossChain', GovHub(proxyGovHub).crosschain());
        console.log('tokenHub', GovHub(proxyGovHub).tokenHub());
        console.log('lightClient', GovHub(proxyGovHub).lightClient());
    }

}
