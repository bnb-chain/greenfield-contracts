// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../contracts/CrossChain.sol";
import "../contracts/middle-layer/GovHub.sol";
import "../contracts/middle-layer/GroupHub.sol";
import "../contracts/tokens/ERC721NonTransferable.sol";
import "../contracts/tokens/ERC1155NonTransferable.sol";
import "../contracts/lib/RLPDecode.sol";
import "../contracts/lib/RLPEncode.sol";

contract GroupHubTest is Test, GroupHub {
    using RLPEncode for *;
    using RLPDecode for *;

    struct ParamChangePackage {
        string key;
        bytes values;
        bytes targets;
    }

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event ReceivedAckPkg(uint8 channelId, bytes msgData, bytes callbackData);
    event ReceivedFailAckPkg(uint8 channelId, bytes msgData, bytes callbackData);

    ERC721NonTransferable public groupToken;
    ERC1155NonTransferable public memberToken;
    GroupHub public groupHub;
    GovHub public govHub;
    CrossChain public crossChain;

    receive() external payable {}

    function setUp() public {
        vm.createSelectFork("test");

        govHub = GovHub(GOV_HUB);
        crossChain = CrossChain(CROSS_CHAIN);
        groupHub = GroupHub(GROUP_HUB);
        groupToken = ERC721NonTransferable(groupHub.ERC721Token());
        memberToken = ERC1155NonTransferable(groupHub.ERC1155Token());

        vm.label(GOV_HUB, "govHub");
        vm.label(GROUP_HUB, "groupHub");
        vm.label(CROSS_CHAIN, "crossChain");
        vm.label(address(groupToken), "groupToken");
        vm.label(address(memberToken), "memberToken");

        groupHub.setFailureHandleStrategy(FailureHandleStrategy.NoCallback);
    }

    function testBasicInfo() public {
        string memory baseUri = groupToken.baseURI();
        assertEq(baseUri, "group");
    }

    function testGov() public {
        ParamChangePackage memory proposal = ParamChangePackage({
            key: "ERC721BaseURI",
            values: bytes("newGroup"),
            targets: abi.encodePacked(address(groupHub))
        });
        bytes memory msgBytes = _encodeGovSynPackage(proposal);

        vm.expectEmit(true, true, false, true, address(groupHub));
        emit ParamChange("ERC721BaseURI", bytes("newGroup"));
        vm.prank(CROSS_CHAIN);
        govHub.handleSynPackage(GOV_CHANNEL_ID, msgBytes);

        proposal.key = "ERC1155BaseURI";
        proposal.values = bytes("newGroupMember");
        msgBytes = _encodeGovSynPackage(proposal);

        vm.expectEmit(true, true, false, true, address(groupHub));
        emit ParamChange("ERC1155BaseURI", bytes("newGroupMember"));
        vm.prank(CROSS_CHAIN);
        govHub.handleSynPackage(GOV_CHANNEL_ID, msgBytes);
    }

    function testMirror(uint256 id) public {
        CmnMirrorSynPackage memory mirrorSynPkg = CmnMirrorSynPackage({id: id, owner: address(this)});
        bytes memory msgBytes = _encodeMirrorSynPackage(mirrorSynPkg);

        vm.expectEmit(true, true, true, true, address(groupToken));
        emit Transfer(address(0), address(this), id);
        vm.prank(CROSS_CHAIN);
        groupHub.handleSynPackage(GROUP_CHANNEL_ID, msgBytes);
    }

    function testCreate(uint256 id) public {
        vm.expectEmit(true, true, true, true, address(groupHub));
        emit CreateSubmitted(address(this), address(this), "test", 2e15, 2e15);
        groupHub.createGroup{value: 41e14}(address(this), "test", address(this), "");

        bytes memory msgBytes =
            _encodeCreateAckPackage(0, id, address(this), address(this), FailureHandleStrategy.NoCallback);

        uint64 sequence = crossChain.channelReceiveSequenceMap(GROUP_CHANNEL_ID);
        vm.expectEmit(true, true, true, true, address(groupToken));
        emit Transfer(address(0), address(this), id);
        vm.prank(CROSS_CHAIN);
        groupHub.handleAckPackage(GROUP_CHANNEL_ID, sequence, msgBytes);
    }

    function testDelete(uint256 id) public {
        vm.prank(GROUP_HUB);
        groupToken.mint(address(this), id);

        vm.expectEmit(true, true, true, true, address(groupHub));
        emit DeleteSubmitted(address(this), address(this), id, 2e15, 2e15);
        groupHub.deleteGroup{value: 41e14}(id, address(this), "");

        bytes memory msgBytes = _encodeDeleteAckPackage(0, id, address(this), FailureHandleStrategy.NoCallback);

        uint64 sequence = crossChain.channelReceiveSequenceMap(GROUP_CHANNEL_ID);
        vm.startPrank(CROSS_CHAIN);
        vm.expectEmit(true, true, true, true, address(groupToken));
        emit Transfer(address(this), address(0), id);
        groupHub.handleAckPackage(GROUP_CHANNEL_ID, sequence, msgBytes);
    }

    function testUpdate(uint256 id) public {
        vm.prank(GROUP_HUB);
        groupToken.mint(address(this), id);

        address[] memory newMembers = new address[](3);
        for (uint256 i; i < 3; i++) {
            newMembers[i] = address(uint160(i + 1));
        }
        UpdateSynPackage memory synPkg =
            UpdateSynPackage({operator: address(this), id: id, opType: UPDATE_ADD, members: newMembers, extraData: ""});

        vm.expectEmit(true, true, true, true, address(groupHub));
        emit UpdateSubmitted(address(this), address(this), id, UPDATE_ADD, newMembers, 2e15, 2e15);
        groupHub.updateGroup{value: 41e14}(synPkg, address(this), "");

        UpdateAckPackage memory updateAckPkg = UpdateAckPackage({
            status: STATUS_SUCCESS,
            operator: address(this),
            id: id,
            opType: UPDATE_ADD,
            members: newMembers,
            extraData: ""
        });
        bytes memory msgBytes = _encodeUpdateAckPackage(updateAckPkg, address(this), FailureHandleStrategy.NoCallback);

        uint64 sequence = crossChain.channelReceiveSequenceMap(GROUP_CHANNEL_ID);
        vm.expectEmit(true, true, true, true, address(memberToken));
        emit TransferSingle(address(groupHub), address(0), address(1), id, 1);
        emit TransferSingle(address(groupHub), address(0), address(2), id, 1);
        emit TransferSingle(address(groupHub), address(0), address(3), id, 1);
        vm.prank(CROSS_CHAIN);
        groupHub.handleAckPackage(GROUP_CHANNEL_ID, sequence, msgBytes);
    }

    function testGrantAndRevoke() public {
        address granter = msg.sender;
        address operator = address(this);

        // failed without authorization
        vm.expectRevert(bytes("no permission to create"));
        groupHub.createGroup{value: 41e14}(granter, "test1", address(this), "");

        // wrong auth code
        uint256 expireTime = block.timestamp + 1 days;
        uint32 authCode = 8;
        vm.expectRevert(bytes("invalid authorization code"));
        vm.prank(msg.sender);
        groupHub.grant(operator, authCode, expireTime);

        // grant
        authCode = 3; // create and delete
        vm.prank(msg.sender);
        groupHub.grant(operator, authCode, expireTime);

        // create success
        vm.expectEmit(true, true, true, true, address(groupHub));
        emit CreateSubmitted(granter, operator, "test1", 2e15, 2e15);
        groupHub.createGroup{value: 41e14}(granter, "test1", address(this), "");

        // delete success
        uint256 tokenId = 0;
        vm.prank(GROUP_HUB);
        groupToken.mint(granter, tokenId);

        vm.expectEmit(true, true, true, true, address(groupHub));
        emit DeleteSubmitted(granter, operator, tokenId, 2e15, 2e15);
        groupHub.deleteGroup{value: 41e14}(tokenId, address(this), "");

        // grant expire
        vm.warp(expireTime + 1);
        vm.expectRevert(bytes("no permission to create"));
        groupHub.createGroup{value: 41e14}(granter, "test2", address(this), "");

        // revoke and create failed
        expireTime = block.timestamp + 1 days;
        vm.prank(msg.sender);
        groupHub.grant(operator, AUTH_CODE_CREATE, expireTime);
        groupHub.createGroup{value: 41e14}(granter, "test2", address(this), "");

        vm.prank(msg.sender);
        groupHub.revoke(operator, AUTH_CODE_CREATE);

        vm.expectRevert(bytes("no permission to create"));
        groupHub.createGroup{value: 41e14}(granter, "test3", address(this), "");
    }

    function testCallback() public {
        // app closed
        groupHub.setFailureHandleStrategy(FailureHandleStrategy.Closed);
        vm.expectRevert(bytes("application closed"));
        groupHub.createGroup{value: 41e14}(address(this), "test", address(this), "");

        // hand in order
        groupHub.setFailureHandleStrategy(FailureHandleStrategy.HandleInSequence);

        groupHub.createGroup{value: 41e14}(address(this), "test", address(this), "");
        bytes memory msgBytes =
            _encodeCreateAckPackage(0, 0, address(this), address(this), FailureHandleStrategy.HandleInSequence);

        uint64 sequence = crossChain.channelReceiveSequenceMap(GROUP_CHANNEL_ID);
        vm.expectEmit(true, true, true, true, address(this));
        emit ReceivedAckPkg(GROUP_CHANNEL_ID, msgBytes, "");
        vm.prank(CROSS_CHAIN);
        groupHub.handleAckPackage(GROUP_CHANNEL_ID, sequence, msgBytes);
    }

    function testFailAck() public {
        groupHub.setFailureHandleStrategy(FailureHandleStrategy.HandleInSequence);

        groupHub.createGroup{value: 41e14}(address(this), "test", address(this), "");
        bytes memory msgBytes =
            _encodeCreateAckPackage(0, 0, address(this), address(this), FailureHandleStrategy.HandleInSequence);

        uint64 sequence = crossChain.channelReceiveSequenceMap(GROUP_CHANNEL_ID);
        vm.expectEmit(true, true, true, true, address(this));
        emit ReceivedFailAckPkg(GROUP_CHANNEL_ID, msgBytes, "");
        vm.prank(CROSS_CHAIN);
        groupHub.handleFailAckPackage(GROUP_CHANNEL_ID, sequence, msgBytes);
    }

    /*----------------- middle-layer app function -----------------*/
    // override the function in GroupHub
    function handleAckPackage(uint8 channelId, bytes calldata ackPkg, bytes calldata callbackData) external {
        emit ReceivedAckPkg(channelId, ackPkg, callbackData);
    }

    function handleFailAckPackage(uint8 channelId, bytes calldata failPkg, bytes calldata callbackData) external {
        emit ReceivedFailAckPkg(channelId, failPkg, callbackData);
    }

    /*----------------- Internal function -----------------*/
    function _encodeGovSynPackage(ParamChangePackage memory proposal) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](3);
        elements[0] = bytes(proposal.key).encodeBytes();
        elements[1] = proposal.values.encodeBytes();
        elements[2] = proposal.targets.encodeBytes();
        return elements.encodeList();
    }

    function _encodeMirrorSynPackage(CmnMirrorSynPackage memory synPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](2);
        elements[0] = synPkg.id.encodeUint();
        elements[1] = synPkg.owner.encodeAddress();
        return _RLPEncode(TYPE_MIRROR, elements.encodeList());
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

        bytes[] memory elements = new bytes[](4);
        elements[0] = status.encodeUint();
        elements[1] = id.encodeUint();
        elements[2] = creator.encodeAddress();
        elements[3] = _extraDataToBytes(extraData).encodeBytes();
        return _RLPEncode(TYPE_CREATE, elements.encodeList());
    }

    function _encodeDeleteAckPackage(uint32 status, uint256 id, address refundAddr, FailureHandleStrategy failStrategy)
        internal
        view
        returns (bytes memory)
    {
        ExtraData memory extraData = ExtraData({
            appAddress: address(this),
            refundAddress: refundAddr,
            failureHandleStrategy: failStrategy,
            callbackData: ""
        });

        bytes[] memory elements = new bytes[](3);
        elements[0] = status.encodeUint();
        elements[1] = id.encodeUint();
        elements[2] = _extraDataToBytes(extraData).encodeBytes();
        return _RLPEncode(TYPE_DELETE, elements.encodeList());
    }

    function _encodeUpdateAckPackage(
        UpdateAckPackage memory ackPkg,
        address refundAddr,
        FailureHandleStrategy failStrategy
    ) internal view returns (bytes memory) {
        bytes[] memory members = new bytes[](ackPkg.members.length);
        for (uint256 i; i < ackPkg.members.length; ++i) {
            members[i] = ackPkg.members[i].encodeAddress();
        }

        ExtraData memory extraData = ExtraData({
            appAddress: address(this),
            refundAddress: refundAddr,
            failureHandleStrategy: failStrategy,
            callbackData: ""
        });

        bytes[] memory elements = new bytes[](6);
        elements[0] = ackPkg.status.encodeUint();
        elements[1] = ackPkg.operator.encodeAddress();
        elements[2] = ackPkg.id.encodeUint();
        elements[3] = ackPkg.opType.encodeUint();
        elements[4] = members.encodeList();
        elements[5] = _extraDataToBytes(extraData).encodeBytes();
        return _RLPEncode(TYPE_UPDATE, elements.encodeList());
    }
}
