pragma solidity ^0.8.0;

import "./Helper.sol";

contract GroupHubScript is Helper {

    function addMember(address operator, uint256 groupId, address member) public {
        console.log("operator", operator);
        console.log("groupId", groupId);
        console.log("add member", member);

        address[] memory members = new address[](1);
        members[0] = member;
        UpdateGroupSynPackage memory pkg =
            UpdateGroupSynPackage(operator, groupId, UpdateGroupOpType.AddMembers, members, "");

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
            UpdateGroupSynPackage(operator, groupId, UpdateGroupOpType.RemoveMembers, members, "");

        // start broadcast real tx
        vm.startBroadcast();

        groupHub.updateGroup{ value: totalRelayFee }(pkg);

        vm.stopBroadcast();
    }
}
