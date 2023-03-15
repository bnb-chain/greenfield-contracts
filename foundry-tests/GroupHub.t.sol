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
        emit CreateSubmitted(address(this), address(this), "test");
        groupHub.createGroup{value: 4e15}(address(this), "test");

        bytes memory msgBytes = _encodeCreateAckPackage(0, id, address(this));

        uint64 sequence = crossChain.channelReceiveSequenceMap(GROUP_CHANNEL_ID);
        vm.expectEmit(true, true, true, true, address(groupToken));
        emit Transfer(address(0), address(this), id);
        vm.prank(CROSS_CHAIN);
        groupHub.handleAckPackage(GROUP_CHANNEL_ID, sequence, msgBytes, 0);
    }

    function testDelete(uint256 id) public {
        vm.prank(GROUP_HUB);
        groupToken.mint(address(this), id);

        vm.expectEmit(true, true, true, true, address(groupHub));
        emit DeleteSubmitted(address(this), address(this), id);
        groupHub.deleteGroup{value: 4e15}(id);

        bytes memory msgBytes = _encodeDeleteAckPackage(0, id);

        uint64 sequence = crossChain.channelReceiveSequenceMap(GROUP_CHANNEL_ID);
        vm.startPrank(CROSS_CHAIN);
        vm.expectEmit(true, true, true, true, address(groupToken));
        emit Transfer(address(this), address(0), id);
        groupHub.handleAckPackage(GROUP_CHANNEL_ID, sequence, msgBytes, 0);
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
        emit UpdateSubmitted(address(this), address(this), id, UPDATE_ADD, newMembers);
        groupHub.updateGroup{value: 4e15}(synPkg);

        UpdateAckPackage memory updateAckPkg = UpdateAckPackage({
            status: STATUS_SUCCESS,
            operator: address(this),
            id: id,
            opType: UPDATE_ADD,
            members: newMembers,
            extraData: ""
        });
        bytes memory msgBytes = _encodeUpdateAckPackage(updateAckPkg);

        uint64 sequence = crossChain.channelReceiveSequenceMap(GROUP_CHANNEL_ID);
        vm.expectEmit(true, true, true, true, address(memberToken));
        emit TransferSingle(address(groupHub), address(0), address(1), id, 1);
        emit TransferSingle(address(groupHub), address(0), address(2), id, 1);
        emit TransferSingle(address(groupHub), address(0), address(3), id, 1);
        vm.prank(CROSS_CHAIN);
        groupHub.handleAckPackage(GROUP_CHANNEL_ID, sequence, msgBytes, 0);
    }

    function testGrantAndRevoke() public {
        address granter = msg.sender;
        address operator = address(this);

        // failed without authorization
        vm.expectRevert(bytes("no permission to create"));
        groupHub.createGroup{value: 4e15}(granter, "test1");

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
        emit CreateSubmitted(granter, operator, "test1");
        groupHub.createGroup{value: 4e15}(granter, "test1");

        // delete success
        uint256 tokenId = 0;
        vm.prank(GROUP_HUB);
        groupToken.mint(granter, tokenId);

        vm.expectEmit(true, true, true, true, address(groupHub));
        emit DeleteSubmitted(granter, operator, tokenId);
        groupHub.deleteGroup{value: 4e15}(tokenId);

        // grant expire
        vm.warp(expireTime + 1);
        vm.expectRevert(bytes("no permission to create"));
        groupHub.createGroup{value: 4e15}(granter, "test2");

        // revoke and create failed
        expireTime = block.timestamp + 1 days;
        vm.prank(msg.sender);
        groupHub.grant(operator, AUTH_CODE_CREATE, expireTime);
        groupHub.createGroup{value: 4e15}(granter, "test2");

        vm.prank(msg.sender);
        groupHub.revoke(operator, AUTH_CODE_CREATE);

        vm.expectRevert(bytes("no permission to create"));
        groupHub.createGroup{value: 4e15}(granter, "test3");
    }

    function testCallback() public {
        bytes memory msgBytes =
            _encodeCreateAckPackage(0, 0, address(this), address(this), FailureHandleStrategy.BlockOnFail);
        uint64 sequence = crossChain.channelReceiveSequenceMap(GROUP_CHANNEL_ID);

        vm.expectEmit(false, false, false, false, address(this));
        emit ReceivedAckPkg(GROUP_CHANNEL_ID, msgBytes, "");
        vm.prank(CROSS_CHAIN);
        groupHub.handleAckPackage(GROUP_CHANNEL_ID, sequence, msgBytes, 5000);
    }

    function testFAck() public {
        ExtraData memory extraData = ExtraData({
            appAddress: address(this),
            refundAddress: address(this),
            failureHandleStrategy: FailureHandleStrategy.BlockOnFail,
            callbackData: ""
        });
        CreateSynPackage memory synPkg =
            CreateSynPackage({creator: address(this), name: "test", extraData: _extraDataToBytes(extraData)});
        bytes memory msgBytes = _encodeCreateSynPackage(synPkg);
        uint64 sequence = crossChain.channelReceiveSequenceMap(GROUP_CHANNEL_ID);

        vm.expectEmit(false, false, false, false, address(this));
        emit ReceivedFailAckPkg(GROUP_CHANNEL_ID, msgBytes, "");
        vm.prank(CROSS_CHAIN);
        groupHub.handleFailAckPackage(GROUP_CHANNEL_ID, sequence, msgBytes, 5000);
    }

    function testRetryPkg() public {
        // callback failed(out of gas)
        bytes memory msgBytes =
            _encodeCreateAckPackage(1, 0, address(this), address(this), FailureHandleStrategy.BlockOnFail);
        uint64 sequence = crossChain.channelReceiveSequenceMap(GROUP_CHANNEL_ID);

        vm.expectEmit(true, false, false, false, address(groupHub));
        emit AppHandleAckPkgFailed(address(this), bytes32(""), "");
        vm.prank(CROSS_CHAIN);
        groupHub.handleAckPackage(GROUP_CHANNEL_ID, sequence, msgBytes, 3000);

        // block on fail
        ExtraData memory extraData = ExtraData({
            appAddress: address(this),
            refundAddress: address(this),
            failureHandleStrategy: FailureHandleStrategy.BlockOnFail,
            callbackData: ""
        });

        vm.expectRevert(bytes("retry queue is not empty"));
        groupHub.createGroup{value: 4e15}(address(this), "test", 0, extraData);

        // retry pkg
        groupHub.retryPackage();
        groupHub.createGroup{value: 4e15}(address(this), "test", 0, extraData);

        // skip on fail
        msgBytes = _encodeCreateAckPackage(1, 0, address(this), address(this), FailureHandleStrategy.SkipOnFail);
        sequence = crossChain.channelReceiveSequenceMap(GROUP_CHANNEL_ID);

        vm.expectEmit(true, false, false, false, address(groupHub));
        emit AppHandleAckPkgFailed(address(this), bytes32(""), "");
        vm.prank(CROSS_CHAIN);
        groupHub.handleAckPackage(GROUP_CHANNEL_ID, sequence, msgBytes, 3000);

        vm.expectRevert(bytes(hex"3db2a12a")); // "Empty()"
        groupHub.retryPackage();
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

    function _encodeCreateAckPackage(uint32 status, uint256 id, address creator) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](3);
        elements[0] = status.encodeUint();
        elements[1] = id.encodeUint();
        elements[2] = creator.encodeAddress();
        return _RLPEncode(TYPE_CREATE, elements.encodeList());
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

    function _encodeDeleteAckPackage(uint32 status, uint256 id) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](2);
        elements[0] = status.encodeUint();
        elements[1] = id.encodeUint();
        return _RLPEncode(TYPE_DELETE, elements.encodeList());
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

    function _encodeUpdateAckPackage(UpdateAckPackage memory ackPkg) internal pure returns (bytes memory) {
        bytes[] memory members = new bytes[](ackPkg.members.length);
        for (uint256 i; i < ackPkg.members.length; ++i) {
            members[i] = ackPkg.members[i].encodeAddress();
        }

        bytes[] memory elements = new bytes[](5);
        elements[0] = ackPkg.status.encodeUint();
        elements[1] = ackPkg.operator.encodeAddress();
        elements[2] = ackPkg.id.encodeUint();
        elements[3] = ackPkg.opType.encodeUint();
        elements[4] = members.encodeList();
        return _RLPEncode(TYPE_UPDATE, elements.encodeList());
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

    function _encodeCreateSynPackage(CreateSynPackage memory synPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](3);
        elements[0] = synPkg.creator.encodeAddress();
        elements[1] = bytes(synPkg.name).encodeBytes();
        elements[2] = synPkg.extraData.encodeBytes();
        return _RLPEncode(TYPE_CREATE, elements.encodeList());
    }
}
