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
    bytes constant public blsPubKeys = hex'8ec21505e290d7c15f789c7b4c522179bb7d70171319bfe2d6b2aae2461a1279566782907593cc526a5f2611c0721d60b4a78719a34817cc1d085b6eed110ed1d1ca59a35c9cf4d094e4e71b0b8b76ac2d30ba0762ec9acfaca8b8b369d914e980e970c25a8580cb0d840dce6fff3adc830e16ec8660fb91c8811a28d8ada91d539f82d2730496549e7783a34167498c';
    address[] public relayers = [0x1115E495c48bEb783ee04Ca99b7c2F87Faf6F8eb, 0x56B2404e087F55D6E16bEED3aDee8F51414A301b, 0xE7B8E0894FF97dd5c846c8A031becDb06E2390ea];

    function run(uint16 _insChainId) public {
        uint256 privateKey = uint256(vm.envBytes32('PK1'));
        address developer = vm.addr(privateKey);

        vm.startBroadcast();

        // deployer contracts
        deployer = new Deployer(_insChainId, blsPubKeys, relayers);
        deployer.deploy();

        // init balance to test
        deployer.proxyTokenHub().transfer(100 ether);

        vm.stopBroadcast();

        address proxyGovHub = deployer.proxyGovHub();

        console.log('GovHub', proxyGovHub);
        console.log('proxyAdmin', GovHub(proxyGovHub).proxyAdmin());
        console.log('crossChain', GovHub(proxyGovHub).crosschain());
        console.log('tokenHub', GovHub(proxyGovHub).tokenHub());
        console.log('lightClient', GovHub(proxyGovHub).lightClient());
    }

}
