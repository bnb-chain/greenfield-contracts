// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "../contracts/Deployer.sol";
import "../contracts/middle-layer/resource-mirror/storage/GroupStorage.sol";
import "../contracts/middle-layer/resource-mirror/storage/BucketStorage.sol";
import "forge-std/Test.sol";

contract Helper is Test, BucketStorage, GroupStorage {
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

        console.log('block.chainid', block.chainid);
        console.log('block.number', block.number);

        assert(deployer.deployed());
        vm.label(deployer.proxyAdmin(), "PROXY_ADMIN");
        vm.label(deployer.proxyGovHub(), "GOV_HUB");
        vm.label(deployer.proxyCrossChain(), "CROSS_CHAIN");
        vm.label(deployer.proxyTokenHub(), "TOKEN_HUB");
        vm.label(deployer.proxyLightClient(), "LIGHT_CLIENT");
        vm.label(deployer.proxyRelayerHub(), "RELAYER_HUB");
        vm.label(deployer.proxyBucketHub(), "BUCKET_HUB");
        vm.label(deployer.proxyObjectHub(), "OBJECT_HUB");
        vm.label(deployer.proxyGroupHub(), "GROUP_HUB");

        vm.label(deployer.implGovHub(), "implGovHub");
        vm.label(deployer.implCrossChain(), "implCrossChain");
        vm.label(deployer.implTokenHub(), "implTokenHub");
        vm.label(deployer.implLightClient(), "implLightClient");
        vm.label(deployer.implRelayerHub(), "implRelayerHub");
        vm.label(deployer.implBucketHub(), "implBucketHub");
        vm.label(deployer.implObjectHub(), "implObjectHub");
        vm.label(deployer.implGroupHub(), "implGroupHub");
        vm.label(deployer.addBucketHub(), "addBucketHub");
        vm.label(deployer.addObjectHub(), "addObjectHub");
        vm.label(deployer.addGroupHub(), "addGroupHub");
        vm.label(deployer.bucketToken(), "bucketToken");
        vm.label(deployer.objectToken(), "objectToken");
        vm.label(deployer.groupToken(), "groupToken");
        vm.label(deployer.memberToken(), "memberToken");
        vm.label(deployer.BucketEncode(), "BucketEncode");
        vm.label(deployer.ObjectEncode(), "ObjectEncode");
        vm.label(deployer.GroupEncode(), "GroupEncode");


        uint256 relayFee = crossChain.relayFee();
        uint256 minAckRelayFee = crossChain.minAckRelayFee();
        totalRelayFee = relayFee + minAckRelayFee;
        console.log('total relay fee', totalRelayFee);
    }

    function getDeployer() public returns (address _deployer) {
        console.log('getDeployer block.chainid', block.chainid);
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
