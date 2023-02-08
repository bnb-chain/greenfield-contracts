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
import "../contracts/Deployer.sol";

contract DeployScript is Script {
    uint16 public constant gnfdChainId = 9000;
    bytes public constant init_cs_bytes =
        hex"677265656e6669656c645f393030302d313231000000000000000000000000000000000000000001a5f1af4874227f1cdbe5240259a365ad86484a4255bfd65e2a0222d733fcdbc320cc466ee9412ddd49e0fff04cdb41bade2b7622f08b6bdacac94d4de03bdb970000000000002710d5e63aeee6e6fa122a6a23a6e0fca87701ba1541aa2d28cbcd1ea3a63479f6fb260a3d755853e6a78cfa6252584fee97b2ec84a9d572ee4a5d3bc1558bb98a4b370fb8616b0b523ee91ad18a63d63f21e0c40a83ef15963f4260574ca5159fd90a1c527000000000000027106fd1ceb5a48579f322605220d4325bd9ff90d5fab31e74a881fc78681e3dfa440978d2b8be0708a1cbbca2c660866216975fdaf0e9038d9b7ccbf9731f43956dba7f2451919606ae20bf5d248ee353821754bcdb456fd3950618fda3e32d3d0fb990eeda000000000000271097376a436bbf54e0f6949b57aa821a90a749920ab32979580ea04984a2be033599c20c7a0c9a8d121b57f94ee05f5eda5b36c38f6e354c89328b92cdd1de33b64d3a0867";

    function run() public {
        vm.startBroadcast();
        Deployer deployer = new Deployer(gnfdChainId);
        payable(deployer.proxyTokenHub()).transfer(100 ether);
        vm.stopBroadcast();

        // add new contracts to Config
        console.log("PROXY_ADMIN", deployer.proxyAdmin());
        console.log("GOV_HUB", deployer.proxyGovHub());
        console.log("CROSS_CHAIN", deployer.proxyCrossChain());
        console.log("TOKEN_HUB", deployer.proxyTokenHub());
        console.log("LIGHT_CLIENT", deployer.proxyLightClient());
        console.log("RELAYER_HUB", deployer.proxyRelayerHub());

        setContractsToConfig(
            deployer.proxyAdmin(),
            deployer.proxyGovHub(),
            deployer.proxyCrossChain(),
            deployer.proxyTokenHub(),
            deployer.proxyLightClient(),
            deployer.proxyRelayerHub()
        );

        vm.startBroadcast();
        address _implGovHub = address(new GovHub());
        address _implCrossChain = address(new CrossChain());
        address _implTokenHub = address(new TokenHub());
        address _implLightClient = address(new GnfdLightClient());
        address _implRelayerHub = address(new RelayerHub());

        deployer.deploy(init_cs_bytes, _implGovHub, _implCrossChain, _implTokenHub, _implLightClient, _implRelayerHub);
        vm.stopBroadcast();
    }

    function setContractsToConfig(
        address _proxyAdmin,
        address _proxyGovHub,
        address _proxyCrossChain,
        address _proxyTokenHub,
        address _proxyLightClient,
        address _proxyRelayerHub
    ) public {
        string[] memory inputs = new string[](8);
        inputs[0] = "node";
        inputs[1] = "./foundry-scripts/setContractsToConfig.js";
        inputs[2] = toString(_proxyAdmin);
        inputs[3] = toString(_proxyGovHub);
        inputs[4] = toString(_proxyCrossChain);
        inputs[5] = toString(_proxyTokenHub);
        inputs[6] = toString(_proxyLightClient);
        inputs[7] = toString(_proxyRelayerHub);

        vm.ffi(inputs);
    }

    function toString(address account) public pure returns (string memory) {
        return toString(abi.encodePacked(account));
    }

    function toString(bytes memory data) public pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < data.length; i++) {
            str[2 + i * 2] = alphabet[uint256(uint8(data[i] >> 4))];
            str[3 + i * 2] = alphabet[uint256(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }
}
