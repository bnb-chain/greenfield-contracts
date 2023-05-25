// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Helper is Script {
    function getDeployer() public returns (address deployer) {
        string memory chainIdString = Strings.toString(block.chainid);
        string[] memory inputs = new string[](4);
        inputs[0] = "bash";
        inputs[1] = "./lib/getDeployer.sh";
        inputs[2] = string.concat("./deployment/", chainIdString, "-deployment.json");

        bytes memory res = vm.ffi(inputs);
        assembly {
            deployer := mload(add(res, 20))
        }
    }
}
