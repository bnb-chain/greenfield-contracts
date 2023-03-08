// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "forge-std/Test.sol";

contract TestDeployer is Test {
    function _deployOnTestChain() internal returns (address deployer1, address deployer2) {
        string[] memory inputs = new string[](3);
        inputs[0] = "npm";
        inputs[1] = "run";
        inputs[2] = "deploy:test";
        vm.ffi(inputs);
        return _getDeployerFromDeployment();
    }

    function _getDeployerFromDeployment() internal returns(address deployer1, address deployer2) {
        vm.createSelectFork("test");
        string[] memory inputs = new string[](3);

        string memory chainIdString = Strings.toString(block.chainid);
        inputs = new string[](4);
        inputs[0] = "bash";
        inputs[1] = "./lib/getDeployer.sh";
        inputs[2] = string.concat("./deployment/", chainIdString, "-deployment.json");
        inputs[3] = "1";

        bytes memory res = vm.ffi(inputs);
        assembly {
            deployer1 := mload(add(res, 20))
        }

        inputs[3] = "2";
        res = vm.ffi(inputs);
        assembly {
            deployer2 := mload(add(res, 20))
        }
    }
}
