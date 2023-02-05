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

contract LightClientScript is Script {
    GnfdLightClient public lightClient;
    bytes public constant init_cs_bytes =
        hex"677265656e6669656c645f393030302d31323100000000000000000000000000000000000000000102462f6e91df5365091f3c59d088c5b759f07ac5dbc0b9b6e320cb9fceae64ce28ea6c6020c829158f042cda713f5095502633ef83730c7174e5463c439476400000000000002710e739795f096affdccbbe7deb706d9bd0f49c499180d2099554bf089a195f03675d3cdb418a97ad9eda4ece38205acdc486e4f3b667b121bb0be2a8bb43b5fe137a702a459f7722bf35eb0de44df3a7fc393c68804446fd9ba45ab29885db037e630f53c40000000000002710ac225b79eccfe6fe2b13e048f3cb232dd4491b528917a8c44f9cc42374d6f485dd492ec2188dd9a9a8a3b7d1226e734aa8f76a7f68c347ac30feedbb2d4db2b2132e758366b2f09a5327fce99ec3aee86c0f78d1de8e04f13b40b72b0659afaf3b519a8e0000000000002710ec5ad68ee64d0c2ecf86e1983f384e7b4b35fb2a96f23fdf8e1b607ce6cbc1d7e8fc6862b825ccee238c4482f503425891efd4bbae807fc0b9895beac181415a8cf5753c";

    function deployAndInit() public {
        uint256 privateKey = uint256(vm.envBytes32("PK1"));
        address developer = vm.addr(privateKey);
        console.log("developer", developer, developer.balance);

        vm.startBroadcast();
        lightClient = new GnfdLightClient();
        lightClient.initialize(init_cs_bytes);
        vm.stopBroadcast();

        console.log("lightClient", address(lightClient));
    }

    function verifyPkg() public {
        uint256 privateKey = uint256(vm.envBytes32("PK1"));
        address developer = vm.addr(privateKey);
        console.log("developer", developer, developer.balance);
        console.log("-------------------------------------------------start verify pkg");

        bytes memory payload =
            hex"10010002010000000000000003000000000063ddf59300000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000eb7b9476d244ce05c3de4bbc6fdd7f56379b145709ade9941ac642f1329404e04850e1dee5e0abe903e62211";
        bytes memory sig =
            hex"b352e9b52ae49bc6ffaf7e975dd7d924ece56b709c88869e22bc832852bf7e033a420f6ca73b74403c46df9f601e323b194602e2ac1fa293f3badf3a306451afa4d071314b73428e99a4da5e444147fe001cb7c7b3d3603a521cbf340e6b1128";
        uint256 bitMap = 7;

        address _lightClient = 0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6;
        vm.startBroadcast();
        GnfdLightClient(_lightClient).verifyPackage(payload, sig, bitMap);
        vm.stopBroadcast();
    }

}
