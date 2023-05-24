pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "../contracts/CrossChain.sol";
import "../contracts/middle-layer/resource-mirror/GroupHub.sol";

contract DevScript is Script {
    address public developer;
    address public crossChain;
    address public groupHub;

    uint256 public relayFee;
    uint256 public minAckRelayFee;

    function setUp() public {
        uint256 privateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        developer = vm.addr(privateKey);
        console.log("developer", developer, developer.balance);

        crossChain = vm.envAddress("CROSS_CHAIN");
        groupHub = vm.envAddress("GROUP_HUB");

        (relayFee, minAckRelayFee) = CrossChain(crossChain).getRelayFees();
    }

    function run() public {
        deleteGroup();
    }

    function createGroup() public {
        vm.startBroadcast(developer);
        GroupHub(groupHub).createGroup{value: relayFee+minAckRelayFee}(developer, "", "test");
        vm.stopBroadcast();
    }

    function deleteGroup() public {
        vm.startBroadcast(developer);
        GroupHub(groupHub).deleteGroup{value: relayFee+minAckRelayFee}(1);
        vm.stopBroadcast();
    }

    function addMember() public {
        address[] memory members = new address[](1);
        members[0] = address(0x1234);

        GroupStorage.UpdateGroupSynPackage memory synPkg = GroupStorage.UpdateGroupSynPackage({
            operator: developer,
            id: 1,
            opType: GroupStorage.UpdateGroupOpType.AddMembers,
            members: members,
            extra: "",
            extraData: ""
        });

        vm.startBroadcast(developer);
        GroupHub(groupHub).updateGroup{value: relayFee+minAckRelayFee}(synPkg);
        vm.stopBroadcast();
    }

    function deleteMember() public {
        address[] memory members = new address[](1);
        members[0] = address(0x1234);

        GroupStorage.UpdateGroupSynPackage memory synPkg = GroupStorage.UpdateGroupSynPackage({
            operator: developer,
            id: 1,
            opType: GroupStorage.UpdateGroupOpType.RemoveMembers,
            members: members,
            extra: "",
            extraData: ""
        });

        vm.startBroadcast(developer);
        GroupHub(groupHub).updateGroup{value: relayFee+minAckRelayFee}(synPkg);
        vm.stopBroadcast();
    }
}
