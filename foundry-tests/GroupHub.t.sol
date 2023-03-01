// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../contracts/middle-layer/GovHub.sol";
import "../contracts/middle-layer/GroupHub.sol";
import "../contracts/tokens/ERC721NonTransferable.sol";
import "../contracts/tokens/ERC1155NonTransferable.sol";
import "../contracts/lib/RLPEncode.sol";
import "../contracts/lib/RLPDecode.sol";

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

    ERC721NonTransferable public groupToken;
    ERC1155NonTransferable public memberToken;
    GroupHub public groupHub;
    GovHub public govHub;

    function setUp() public {
        vm.createSelectFork("test");

        govHub = GovHub(GOV_HUB);
        groupHub = GroupHub(GROUP_HUB);
        groupToken = ERC721NonTransferable(groupHub.ERC721Token());
        memberToken = ERC1155NonTransferable(groupHub.ERC1155Token());

        vm.label(GOV_HUB, "govHub");
        vm.label(GROUP_HUB, "groupHub");
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
        CmnMirrorSynPackage memory mirrorSynPkg = CmnMirrorSynPackage({id: id, owner: msg.sender});
        bytes memory msgBytes = _encodeMirrorSynPackage(mirrorSynPkg);

        vm.expectEmit(true, true, true, true, address(groupToken));
        emit Transfer(address(0), msg.sender, id);
        vm.prank(CROSS_CHAIN);
        groupHub.handleSynPackage(GROUP_CHANNEL_ID, msgBytes);
    }

    function testCreate(uint256 id) public {
        CmnCreateAckPackage memory createAckPkg = CmnCreateAckPackage({status: 0, creator: msg.sender, id: id});
        bytes memory msgBytes = _encodeCreateAckPackage(createAckPkg);

        vm.expectEmit(true, true, true, true, address(groupToken));
        emit Transfer(address(0), msg.sender, id);
        vm.prank(CROSS_CHAIN);
        groupHub.handleAckPackage(GROUP_CHANNEL_ID, msgBytes);
    }

    function testUpdate(uint256 id) public {
        vm.prank(GROUP_HUB);
        groupToken.mint(msg.sender, id);

        address[] memory newMembers = new address[](3);
        for (uint256 i; i < 3; i++) {
            newMembers[i] = address(uint160(i + 1));
        }
        UpdateAckPackage memory updateAckPkg = UpdateAckPackage({
            status: STATUS_SUCCESS,
            operator: msg.sender,
            id: id,
            opType: UPDATE_ADD,
            members: newMembers
        });
        bytes memory msgBytes = _encodeUpdateAckPackage(updateAckPkg);
        vm.expectEmit(true, true, true, true, address(memberToken));
        emit TransferSingle(address(groupHub), address(0), address(1), id, 1);
        emit TransferSingle(address(groupHub), address(0), address(2), id, 1);
        emit TransferSingle(address(groupHub), address(0), address(3), id, 1);
        vm.prank(CROSS_CHAIN);
        groupHub.handleAckPackage(GROUP_CHANNEL_ID, msgBytes);
    }

    function testDelete(uint256 id) public {
        vm.prank(GROUP_HUB);
        groupToken.mint(msg.sender, id);

        CmnDeleteAckPackage memory deleteAckPkg = CmnDeleteAckPackage({status: 0, id: id});
        bytes memory msgBytes = _encodeDeleteAckPackage(deleteAckPkg);

        vm.startPrank(CROSS_CHAIN);
        vm.expectEmit(true, true, true, true, address(groupToken));
        emit Transfer(msg.sender, address(0), id);
        groupHub.handleAckPackage(GROUP_CHANNEL_ID, msgBytes);
    }

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

    function _encodeCreateAckPackage(CmnCreateAckPackage memory ackPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](3);
        elements[0] = ackPkg.status.encodeUint();
        elements[1] = ackPkg.id.encodeUint();
        elements[2] = ackPkg.creator.encodeAddress();
        return _RLPEncode(TYPE_CREATE, elements.encodeList());
    }

    function _encodeDeleteAckPackage(CmnDeleteAckPackage memory ackPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](2);
        elements[0] = ackPkg.status.encodeUint();
        elements[1] = ackPkg.id.encodeUint();
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
}
