// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "./TestDeployer.sol";
import "../contracts/Deployer1.sol";
import "../contracts/Deployer2.sol";
import "../contracts/CrossChain.sol";
import "../contracts/GnfdProxy.sol";
import "../contracts/GnfdLightClient.sol";

contract DeployerTest is TestDeployer {
    Deployer1 deployer1;
    Deployer2 deployer2;

    function setUp() public {}

    function test_calc_create_address() public {
        deployer1 = new Deployer1(1);
        TestAddress testDeployer = new TestAddress();
        testDeployer.deploy();
        for (uint256 i = 0; i < 5; i++) {
            assertEq(
                testDeployer.deployedAddressSet(i), deployer1.calcCreateAddress(address(testDeployer), uint8(i + 1))
            );
        }
    }

    function test_deploy() public {
        (address _deployer1, address _deployer2) = _deployOnTestChain();
        deployer1 = Deployer1(_deployer1);
        deployer2 = Deployer2(_deployer2);
        assertTrue(deployer1.deployed());
        assertTrue(deployer2.deployed());
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
