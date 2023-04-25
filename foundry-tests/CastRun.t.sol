// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "contracts/Deployer.sol";
import "contracts/CrossChain.sol";
import "contracts/middle-layer/GovHub.sol";
import "contracts/middle-layer/TokenHub.sol";
import "./TestDeployer.sol";

contract CastRunTest is TestDeployer {
    Deployer public deployer;
    GovHub public govHub;
    CrossChain public crossChain;
    TokenHub public tokenHub;
    GnfdLightClient public lightClient;
    ProxyAdmin public proxyAdmin;

    address private developer = 0x0000000000000000000000000000000012345678;
    address private user1 = 0x1000000000000000000000000000000012345678;

    function setUp() public {
        vm.createSelectFork("test", 389328);
//        vm.createSelectFork("test");
        console.log('block.chainid', block.chainid);
        console.log('block.number', block.number);

        address _deployer = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
        deployer = Deployer(_deployer);
        assert(deployer.deployed());

        govHub = GovHub(payable(deployer.proxyGovHub()));
        crossChain = CrossChain(payable(deployer.proxyCrossChain()));
        tokenHub = TokenHub(payable(deployer.proxyTokenHub()));
        lightClient = GnfdLightClient(payable(deployer.proxyLightClient()));
        proxyAdmin = ProxyAdmin(payable(deployer.proxyAdmin()));

        vm.label(deployer.proxyGovHub(), "GOV_HUB");
        vm.label(deployer.proxyCrossChain(), "CROSS_CHAIN");
        vm.label(deployer.proxyTokenHub(), "TOKEN_HUB");
        vm.label(deployer.proxyLightClient(), "LIGHT_CLIENT");
        vm.label(deployer.proxyAdmin(), "PROXY_ADMIN");

        address newImplCrossChain = address(new CrossChain());
        address newImplLightClient = address(new GnfdLightClient());
        address newImplGovHub = address(new GovHub());
        vm.startPrank(deployer.proxyGovHub());
        proxyAdmin.upgrade(TransparentUpgradeableProxy(payable(deployer.proxyCrossChain())), newImplCrossChain);
        proxyAdmin.upgrade(TransparentUpgradeableProxy(payable(deployer.proxyLightClient())), newImplLightClient);
        proxyAdmin.upgrade(TransparentUpgradeableProxy(payable(deployer.proxyGovHub())), newImplGovHub);
        vm.stopPrank();

        vm.deal(developer, 10000 ether);
    }

    function test_handlePackage() public {
        bytes memory data = hex"c9978d2400000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000003f000000000000000000000000000000000000000000000000000000000000008915e015e101000000000000025300000000006438c35c0000000000000000000000000000000000000000000000000000e35fa931a0000000000000000000000000000000000000000000000000000000000000000000f2871550f7dca7000094b1e59e9de791e27bc78573eaf59e85c27e88cfd794b1e59e9de791e27bc78573eaf59e85c27e88cfd70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006090a97ca0de89b7a025fbffe1d7b8c992311b5c37b377d8e447083763e8c8334dc181268f47664c4b333ba8b302dbfa6311f053e03cbd8b5d414cd746d176e7023d4d3ff2a55d18020f10402b299289c2ac3c491d100807ff3b36f43e112bf5f0";
        address relayer = 0x414FEBEB91dbb7c174298918326D406A11ffE127;

        vm.startPrank(relayer, relayer);
        (bool success, bytes memory returnData) = address(crossChain).call(data);
        console.log('success', success);
        vm.stopPrank();
    }

    function iToHex(bytes memory buffer) public pure returns (string memory) {
        // Fixed buffer size for hexadecimal convertion
        bytes memory converted = new bytes(buffer.length * 2);
        bytes memory _base = "0123456789abcdef";
        for (uint256 i = 0; i < buffer.length; i++) {
            converted[i * 2] = _base[uint8(buffer[i]) / _base.length];
            converted[i * 2 + 1] = _base[uint8(buffer[i]) % _base.length];
        }
        return string(abi.encodePacked("0x", converted));
    }
}
