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

contract GroupHubScript is Script, GroupStorage {
    GroupHub public constant groupHub = GroupHub(address(0x275039fc0fd2eeFac30835af6aeFf24e8c52bA6B));

    function updateGroup(address operator, uint256 groupId, address member) public {
        console.log("operator", operator);
        console.log("groupId", groupId);
        console.log("members 0", member);

        uint256 relayFee = 50e13;

        address[] memory members = new address[](1);
        members[0] = member;
        UpdateGroupSynPackage memory pkg =
            UpdateGroupSynPackage(operator, groupId, UpdateGroupOpType.AddMembers, members, "", "");

        vm.startBroadcast();
        groupHub.updateGroup{ value: relayFee }(pkg);
        vm.stopBroadcast();
    }
}
