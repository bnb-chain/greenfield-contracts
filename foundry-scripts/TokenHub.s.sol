pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../contracts/GnfdProxy.sol";
import "../contracts/GnfdProxyAdmin.sol";
import "../contracts/GnfdLightClient.sol";
import "../contracts/CrossChain.sol";
import "../contracts/middle-layer/GovHub.sol";
import "../contracts/middle-layer/TokenHub.sol";

contract TokenHubScript is Script {
    TokenHub private tokenHub;

    function run(address payable proxyTokenHub, address receipt, uint256 amount) public {
        tokenHub = TokenHub(proxyTokenHub);
        uint256 privateKey = uint256(vm.envBytes32("DeployerPrivateKey"));
        address developer = vm.addr(privateKey);
        console.log('developer', developer, developer.balance);

        vm.startBroadcast();
        tokenHub.transferOut{value: amount + 1 ether}(receipt, amount);
        vm.stopBroadcast();
    }
}
