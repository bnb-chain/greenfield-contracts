// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "contracts/CrossChain.sol";
import "contracts/middle-layer/GovHub.sol";
import "contracts/middle-layer/resource-mirror/MultiMessage.sol";
import "contracts/middle-layer/resource-mirror/AdditionalBucketHub.sol";
import "contracts/middle-layer/resource-mirror/GroupHub.sol";
import "contracts/tokens/ERC721NonTransferable.sol";

contract MultiMessageTest is Test, MultiMessage {
    struct ParamChangePackage {
        string key;
        bytes values;
        bytes targets;
    }

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event GreenfieldCall(
        uint32 indexed status,
        uint8 channelId,
        uint8 indexed operationType,
        uint256 indexed resourceId,
        bytes callbackData
    );

    ERC721NonTransferable public permissionToken;
    MultiMessage public multiMessage;
    GovHub public govHub;
    GroupHub public groupHub;
    CrossChain public crossChain;

    receive() external payable {}

    function setUp() public {
        vm.createSelectFork("local");

        govHub = GovHub(GOV_HUB);
        groupHub = GroupHub(GROUP_HUB);
        crossChain = CrossChain(CROSS_CHAIN);
        multiMessage = MultiMessage(MULTI_MESSAGE);
        permissionToken = ERC721NonTransferable(multiMessage.ERC721Token());

        vm.label(GOV_HUB, "GOV_HUB");
        vm.label(MULTI_MESSAGE, "MULTI_MESSAGE");
        vm.label(CROSS_CHAIN, "CROSS_CHAIN");
        vm.label(GROUP_HUB, "GROUP_HUB");

        vm.deal(address(this), 10000 ether);
    }

    function testSendMessages() public {
        address[] memory _targets = new address[](2);
        bytes[] memory _data = new bytes[](2);
        uint256[] memory _values = new uint256[](2);

        _targets[0] = GROUP_HUB;
        _targets[1] = GROUP_HUB;

        // abi.encodeWithSignature("log(string,uint256)", p0, p1)
        _data[0] = abi.encodeWithSignature("prepareCreateGroup(address,address,string)", address(this), address(this), "test1");
        _data[1] = abi.encodeWithSignature("prepareCreateGroup(address,address,string)", address(this), address(this), "test2");

        _values[0] = 0.1 ether;
        _values[1] = 0.1 ether;

        multiMessage.sendMessages{ value: 0.2 ether }(_targets, _data, _values);
    }

    function testPrepareCreateGroup() public {
        vm.startPrank(MULTI_MESSAGE);

//        bytes memory _data = abi.encodeWithSignature("prepareCreateGroup(address,address,string)", address(this), address(this), "test1");
//        address(multiMessage).call(_data);

        groupHub.prepareCreateGroup(address(this), address(this), "test1");

        vm.stopPrank();
    }


    function testDecode() public {
        bytes memory _data = hex'000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000022000000000000000000000000000000000000000000000000000000000000001c0000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000e35fa931a00000000000000000000000000000000000000000000000000001626218b45860000000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e149600000000000000000000000000000000000000000000000000000000000000e10200000000000000000000000000000000000000000000000000000000000000200000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000005746573743100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001c0000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000e35fa931a00000000000000000000000000000000000000000000000000001626218b45860000000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e149600000000000000000000000000000000000000000000000000000000000000e10200000000000000000000000000000000000000000000000000000000000000200000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000057465737432000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000';
        bytes[] memory messages = abi.decode(_data, (bytes[]));
/*
        for (uint256 i = 0; i < messages.length; ++i) {
            (uint8 channelId, bytes memory msgBytes, uint256 relayFee, uint256 ackRelayFee, address sender) = abi.decode(
                messages[i],
                (uint8, bytes, uint256, uint256, address)
            );

            console.log("status: ", channelId);
            console.logBytes(msgBytes);
            console.log("relayFee: ", relayFee);
            console.log("ackRelayFee: ", ackRelayFee);
            console.log("sender: ", sender);
        }

        */

        bytes memory _data2 = hex'000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000e35fa931a00000000000000000000000000000000000000000000000000001626218b45860000000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e149600000000000000000000000000000000000000000000000000000000000000e10200000000000000000000000000000000000000000000000000000000000000200000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000057465737431000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000';
        (uint8 channelId, bytes memory msgBytes, uint256 relayFee, uint256 ackRelayFee, address sender) = abi.decode(
            _data2,
            (uint8, bytes, uint256, uint256, address)
        );

        console.log("channelId: ", channelId);
        console.logBytes(msgBytes);
        console.log("relayFee: ", relayFee);
        console.log("ackRelayFee: ", ackRelayFee);
        console.log("sender: ", sender);
    }

    /*----------------- dApp function -----------------*/
    function greenfieldCall(
        uint32 status,
        uint8 channelId,
        uint8 operationType,
        uint256 resourceId,
        bytes memory callbackData
    ) external {
        emit GreenfieldCall(status, channelId, operationType, resourceId, callbackData);
    }

    /*----------------- Internal function -----------------*/
    function _encodeGovSynPackage(ParamChangePackage memory proposal) internal pure returns (bytes memory) {
        return abi.encode(proposal);
    }

    function _encodeCreateAckPackage(uint32 status, uint256 id, address creator) internal pure returns (bytes memory) {
        return abi.encodePacked(TYPE_CREATE, abi.encode(CmnCreateAckPackage(status, id, creator, "")));
    }

    function _encodeCreateAckPackage(
        uint32 status,
        uint256 id,
        address creator,
        address refundAddr,
        FailureHandleStrategy failStrategy
    ) internal view returns (bytes memory) {
        ExtraData memory extraData = ExtraData({
            appAddress: address(this),
            refundAddress: refundAddr,
            failureHandleStrategy: failStrategy,
            callbackData: ""
        });
        return abi.encodePacked(TYPE_CREATE, abi.encode(CmnCreateAckPackage(status, id, creator, abi.encode(extraData))));
    }

    function _encodeDeleteAckPackage(uint32 status, uint256 id) internal pure returns (bytes memory) {
        return abi.encodePacked(TYPE_DELETE, abi.encode(CmnDeleteAckPackage(status, id, "")));
    }

    function _encodeDeleteAckPackage(
        uint32 status,
        uint256 id,
        address refundAddr,
        FailureHandleStrategy failStrategy
    ) internal view returns (bytes memory) {
        ExtraData memory extraData = ExtraData({
            appAddress: address(this),
            refundAddress: refundAddr,
            failureHandleStrategy: failStrategy,
            callbackData: ""
        });
        return abi.encodePacked(TYPE_DELETE, abi.encode(CmnDeleteAckPackage(status, id, abi.encode(extraData))));
    }
}
