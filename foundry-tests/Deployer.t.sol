pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "forge-std/Test.sol";

import "../contracts/Deployer.sol";
import "../contracts/CrossChain.sol";
import "../contracts/GnfdProxy.sol";
import "../contracts/GnfdProxyAdmin.sol";
import "../contracts/GnfdLightClient.sol";
import "../contracts/middle-layer/GovHub.sol";
import "../contracts/middle-layer/TokenHub.sol";

contract DeployerTest is Test {
    Deployer deployer;

    function setUp() public {}

    function test_calc_create_address() public {
        deployer = new Deployer(1);
        TestDeployer testDeployer = new TestDeployer();
        testDeployer.deploy();
        for (uint256 i = 0; i < 5; i++) {
            assertEq(
                testDeployer.deployedAddressSet(i), deployer.calcCreateAddress(address(testDeployer), uint8(i + 1))
            );
        }
    }

    function test_deploy() public {
        string[] memory inputs = new string[](3);
        inputs[0] = "npm";
        inputs[1] = "run";
        inputs[2] = "deploy:test";
        vm.ffi(inputs);


        vm.createSelectFork("test");
        string memory chainIdString = Strings.toString(block.chainid);
        inputs[0] = "bash";
        inputs[1] = "./lib/getDeployer.sh";
        inputs[2] = string.concat("./deployment/", chainIdString, "-deployment.json");

        bytes memory res = vm.ffi(inputs);
        address _deployer;
        assembly {
            _deployer := mload(add(res, 20))
        }
        deployer = Deployer(_deployer);
        assert(deployer.deployed());
    }
}

contract TestDeployer {
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
