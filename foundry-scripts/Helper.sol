// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../contracts/middle-layer/resource-mirror/GroupHub.sol";
import "../contracts/Deployer.sol";

contract Helper is Script {
    Deployer public deployer;

    ProxyAdmin public proxyAdmin;
    GovHub public govHub;
    CrossChain public crossChain;
    TokenHub public tokenHub;
    GnfdLightClient public lightClient;
    RelayerHub public relayerHub;
    BucketHub public bucketHub;
    ObjectHub public objectHub;
    GroupHub public groupHub;

    uint256 public totalRelayFee;

    constructor() {
        deployer = Deployer(getDeployer());
        proxyAdmin = ProxyAdmin(payable(deployer.proxyAdmin()));
        govHub = GovHub(payable(deployer.proxyGovHub()));
        crossChain = CrossChain(payable(deployer.proxyCrossChain()));
        tokenHub = TokenHub(payable(deployer.proxyTokenHub()));
        lightClient = GnfdLightClient(payable(deployer.proxyLightClient()));
        relayerHub = RelayerHub(payable(deployer.proxyRelayerHub()));
        bucketHub = BucketHub(payable(deployer.proxyBucketHub()));
        objectHub = ObjectHub(payable(deployer.proxyObjectHub()));
        groupHub = GroupHub(payable(deployer.proxyGroupHub()));



        uint256 relayFee = crossChain.relayFee();
        uint256 minAckRelayFee = crossChain.minAckRelayFee();
        totalRelayFee = relayFee + minAckRelayFee;

        console.log('total relay fee', totalRelayFee);
    }

    function getDeployer() public returns (address _deployer) {
        string memory chainIdString = Strings.toString(block.chainid);
        string[] memory inputs = new string[](4);
        inputs[0] = "bash";
        inputs[1] = "./lib/getDeployer.sh";
        inputs[2] = string.concat("./deployment/", chainIdString, "-deployment.json");

        bytes memory res = vm.ffi(inputs);
        assembly {
            _deployer := mload(add(res, 20))
        }
    }
}
