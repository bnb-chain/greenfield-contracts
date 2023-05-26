pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../contracts/GnfdProxy.sol";
import "../contracts/GnfdProxyAdmin.sol";
import "../contracts/GnfdLightClient.sol";
import "../contracts/CrossChain.sol";
import "../contracts/middle-layer/GovHub.sol";
import "../contracts/middle-layer/TokenHub.sol";
import "../contracts/middle-layer/resource-mirror/GroupHub.sol";
import "../contracts/middle-layer/resource-mirror/storage/GroupStorage.sol";
import "../contracts/Deployer.sol";
import "./Helper.sol";

contract GroupHubScript is Helper, GroupStorage {

    function addMember(address operator, uint256 groupId, address member) public {
        console.log("operator", operator);
        console.log("groupId", groupId);
        console.log("add member", member);

        address[] memory members = new address[](1);
        members[0] = member;
        UpdateGroupSynPackage memory pkg =
            UpdateGroupSynPackage(operator, groupId, UpdateGroupOpType.AddMembers, members, "", "");

        // start broadcast real tx
        vm.startBroadcast();

        groupHub.updateGroup{ value: totalRelayFee }(pkg);

        vm.stopBroadcast();
    }

    function removeMember(address operator, uint256 groupId, address member) public {
        console.log("operator", operator);
        console.log("groupId", groupId);
        console.log("remove member", member);

        address[] memory members = new address[](1);
        members[0] = member;
        UpdateGroupSynPackage memory pkg =
            UpdateGroupSynPackage(operator, groupId, UpdateGroupOpType.RemoveMembers, members, "", "");

        // start broadcast real tx
        vm.startBroadcast();

        groupHub.updateGroup{ value: totalRelayFee }(pkg);

        vm.stopBroadcast();
    }
}
