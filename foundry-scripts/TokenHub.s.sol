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

contract TokenHubScript is Script {
    TokenHub private tokenHub;

    function run(address proxyTokenHub, address receipt, uint256 amount) public {
        tokenHub = TokenHub(proxyTokenHub);
        uint256 privateKey = uint256(vm.envBytes32('PK1'));
        address developer = vm.addr(privateKey);

        vm.startBroadcast();
        tokenHub.transferOut(receipt, amount);
        vm.stopBroadcast();
    }

}
