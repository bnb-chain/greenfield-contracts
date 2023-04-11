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
        vm.createSelectFork("test", 373779);
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
        bytes memory data = hex"c9978d2400000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000001f00000000000000000000000000000000000000000000000000000000000000a1232802ca030000000000000030000000000064337b4200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f84992626174636853697a65466f724f7261636c65a0000000000000000000000000000000000000000000000000000000000000004b947ab4c4804197531f7ed6a6bc0f0781f706ff7953000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060938721719effce0d905fe5a29babc39b9fa844bca8bbfdb37c7217f30917798cd21a316e5cac2dfa3414edfbf80eeb920aa755c461ffa2644184599ffe9da2121285acec7c2c43a0bff07d4b8d0a8af064578de8f99823f6ea12ef88cb750c2a";
        address relayer = 0x6bbcCa3CA63FBCBB1Cfe7CAd53ef865Ae3684335;

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
