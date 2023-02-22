pragma solidity ^0.8.0;

import "./TestDeployer.sol";
import "../contracts/Deployer.sol";
import "../contracts/CrossChain.sol";
import "../contracts/GnfdProxy.sol";
import "../contracts/GnfdProxyAdmin.sol";
import "../contracts/GnfdLightClient.sol";
import "../contracts/middle-layer/GovHub.sol";
import "../contracts/middle-layer/TokenHub.sol";

contract DeployerTest is TestDeployer {
    Deployer deployer;

    function setUp() public {}

    function test_calc_create_address() public {
        deployer = new Deployer(1);
        TestAddress testDeployer = new TestAddress();
        testDeployer.deploy();
        for (uint256 i = 0; i < 5; i++) {
            assertEq(
                testDeployer.deployedAddressSet(i), deployer.calcCreateAddress(address(testDeployer), uint8(i + 1))
            );
        }
    }

    function test_deploy() public {
        address _deployer = _deployOnTestChain();
        deployer = Deployer(_deployer);
        assertTrue(deployer.deployed());
    }
}

contract TestAddress {
    address[] public deployedAddressSet;

    constructor() {
        deployedAddressSet.push(address(new CrossChain()));
        deployedAddressSet.push(address(new GnfdLightClient()));
        deployedAddressSet.push(address(new GnfdProxy(deployedAddressSet[0], deployedAddressSet[0], "")));
    }

    function deploy() public {
        deployedAddressSet.push(address(new GnfdLightClient()));
        deployedAddressSet.push(address(new GnfdLightClient()));
    }
}
