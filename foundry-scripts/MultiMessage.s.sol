pragma solidity ^0.8.0;

import "./Helper.sol";

contract MultiMessageScript is Helper {

    function multiMessageTransferOut(address receiver, uint256 amount) public {
        console.log('sender', tx.origin);
        console.log('receiver', receiver);

        address[] memory _targets = new address[](2);
        _targets[0] = address(tokenHub);
        _targets[1] = address(tokenHub);

        bytes[] memory _data = new bytes[](2);
        _data[0] = abi.encodeWithSignature("prepareTransferOut(address,address,uint256)", tx.origin, receiver, amount);
        _data[1] = abi.encodeWithSignature("prepareTransferOut(address,address,uint256)", tx.origin, receiver, amount * 2);

        uint256[] memory _values = new uint256[](2);
        _values[0] = amount + totalRelayFee;
        _values[1] = amount * 2 + totalRelayFee;

        console.log('total value of tx1', _values[0]);
        console.log('total value of tx2', _values[1]);


        // start broadcast real tx
        vm.startBroadcast();
        multiMessage.sendMessages{ value: _values[0] + _values[1] }(_targets, _data, _values);
        vm.stopBroadcast();
    }

    function groupMultiMessage() public {
        address sender = tx.origin;
        console.log('sender', sender);

        address[] memory _targets = new address[](2);
        _targets[0] = address(groupHub);
        _targets[1] = address(groupHub);

        bytes[] memory _data = new bytes[](2);
        _data[0] = abi.encodeWithSignature("prepareCreateGroup(address,address,string)", sender, sender, "test1");
        _data[1] = abi.encodeWithSignature("prepareCreateGroup(address,address,string)", sender, sender, "test2");

        uint256[] memory _values = new uint256[](2);
        _values[0] = totalRelayFee;
        _values[1] = totalRelayFee;

        console.log('total value of tx1', _values[0]);
        console.log('total value of tx2', _values[1]);

        // start broadcast real tx
        vm.startBroadcast();
        multiMessage.sendMessages{ value: _values[0] + _values[1] }(_targets, _data, _values);
        vm.stopBroadcast();
    }

    function groupAddMember() public {
        address sender = tx.origin;
        console.log('sender', sender);

        address member = 0x0000000000000000000000000000000000001234;
        console.log('member', member);

        address[] memory _targets = new address[](2);
        _targets[0] = address(groupHub);
        _targets[1] = address(groupHub);

        bytes[] memory _data = new bytes[](2);
        _data[0] = abi.encodeWithSignature("prepareCreateGroup(address,address,string)", sender, sender, "test3");

        address[] memory members = new address[](1);
        members[0] = member;

        uint64[] memory memberExpiration = new uint64[](1);
        memberExpiration[0] = uint64(block.timestamp + 1000000);

        UpdateGroupSynPackage memory synPkg = UpdateGroupSynPackage({
            operator: sender,
            id: 3,
            opType: UpdateGroupOpType.AddMembers,
            members: members,
            extraData: "", // abi.encode of ExtraData
            memberExpiration: memberExpiration // timestamp(UNIX) of member expiration
        });
        _data[1] = abi.encodeCall(IGroupHub.prepareUpdateGroup, (sender, synPkg));

        uint256[] memory _values = new uint256[](2);
        _values[0] = totalRelayFee;
        _values[1] = totalRelayFee;

        console.log('total value of tx1', _values[0]);
        console.log('total value of tx2', _values[1]);

        // start broadcast real tx
        vm.startBroadcast();
        multiMessage.sendMessages{ value: _values[0] + _values[1] }(_targets, _data, _values);
        vm.stopBroadcast();
    }
}
