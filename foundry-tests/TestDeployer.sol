// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "forge-std/Test.sol";

contract TestDeployer is Test {
    function _deployOnTestChain() internal returns (address deployer) {
        string[] memory inputs = new string[](3);
        inputs[0] = "npm";
        inputs[1] = "run";
        inputs[2] = "deploy:test";
        vm.ffi(inputs);

        vm.createSelectFork("test");

        string memory chainIdString = Strings.toString(block.chainid);
        inputs = new string[](4);
        inputs[0] = "bash";
        inputs[1] = "./lib/getDeployer.sh";
        inputs[2] = string.concat("./deployment/", chainIdString, "-deployment.json");

        bytes memory res = vm.ffi(inputs);
        assembly {
            deployer := mload(add(res, 20))
        }
    }
}
