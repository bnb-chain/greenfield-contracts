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

contract CrossChainScript is Script {
    CrossChain private crosschain;

    function run(bytes calldata _payload, bytes calldata _blsSignature, uint256 _validatorsBitSet) public {
        uint256 privateKey = uint256(vm.envBytes32('PK1'));
        address developer = vm.addr(privateKey);
        console.log("developer", developer);

        vm.startBroadcast();

        crosschain.handlePackage(_payload, _blsSignature, _validatorsBitSet);

        vm.stopBroadcast();
    }

}
