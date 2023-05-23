// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "forge-std/Test.sol";
import "../contracts/Config.sol";

contract TestDeployer is Test, Config {
    constructor() {
        vm.label(PROXY_ADMIN, "PROXY_ADMIN");
        vm.label(GOV_HUB, "GOV_HUB");
        vm.label(CROSS_CHAIN, "CROSS_CHAIN");
        vm.label(TOKEN_HUB, "TOKEN_HUB");
        vm.label(LIGHT_CLIENT, "LIGHT_CLIENT");
        vm.label(RELAYER_HUB, "RELAYER_HUB");
        vm.label(BUCKET_HUB, "BUCKET_HUB");
        vm.label(OBJECT_HUB, "OBJECT_HUB");
        vm.label(GROUP_HUB, "GROUP_HUB");
    }

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
