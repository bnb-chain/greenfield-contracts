// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../contracts/middle-layer/GovHub.sol";
import "../contracts/middle-layer/BucketHub.sol";

import "../contracts/tokens/ERC721NonTransferable.sol";

import "../contracts/lib/RLPEncode.sol";
import "../contracts/lib/RLPDecode.sol";

contract BucketHubTest is Test, BucketHub {
    using RLPEncode for *;
    using RLPDecode for *;

    struct ParamChangePackage {
        string key;
        bytes values;
        bytes targets;
    }

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    ERC721NonTransferable public bucketToken;
    BucketHub public bucketHub;
    GovHub public govHub;

    function setUp() public {
        vm.createSelectFork("test");

        govHub = GovHub(GOV_HUB);
        bucketHub = BucketHub(BUCKET_HUB);
        bucketToken = ERC721NonTransferable(bucketHub.ERC721Token());

        vm.label(GOV_HUB, "govHub");
        vm.label(BUCKET_HUB, "bucketHub");
        vm.label(address(bucketToken), "bucketToken");
    }

    function testBasicInfo() public {
        string memory baseUri = bucketToken.baseURI();
        assertEq(baseUri, "bucket");
    }

    function testGov() public {
        ParamChangePackage memory proposal = ParamChangePackage({
            key: "BaseURI",
            values: bytes("newBucket"),
            targets: abi.encodePacked(address(bucketHub))
        });
        bytes memory msgBytes = _encodeGovSynPackage(proposal);

        vm.expectEmit(true, true, false, true, address(bucketHub));
        emit ParamChange("BaseURI", bytes("newBucket"));
        vm.prank(CROSS_CHAIN);
        govHub.handleSynPackage(GOV_CHANNEL_ID, msgBytes);
    }

    function testMirror(uint256 id) public {
        CmnMirrorSynPackage memory mirrorSynPkg = CmnMirrorSynPackage({id: id, key: bytes("test"), owner: msg.sender});
        bytes memory msgBytes = _encodeMirrorSynPackage(mirrorSynPkg);

        vm.expectEmit(true, true, true, true, address(bucketToken));
        emit Transfer(address(0), msg.sender, id);
        vm.prank(CROSS_CHAIN);
        bucketHub.handleSynPackage(BUCKET_CHANNEL_ID, msgBytes);
    }

    function testCreate(uint256 id) public {
        CmnCreateAckPackage memory createAckPkg = CmnCreateAckPackage({status: 0, creator: msg.sender, id: id});
        bytes memory msgBytes = _encodeCreateAckPackage(createAckPkg);

        vm.expectEmit(true, true, true, true, address(bucketToken));
        emit Transfer(address(0), msg.sender, id);
        vm.prank(CROSS_CHAIN);
        bucketHub.handleAckPackage(BUCKET_CHANNEL_ID, msgBytes);
    }

    function testDelete(uint256 id) public {
        vm.prank(BUCKET_HUB);
        bucketToken.mint(msg.sender, id);

        CmnDeleteAckPackage memory deleteAckPkg = CmnDeleteAckPackage({status: 0, id: id});
        bytes memory msgBytes = _encodeDeleteAckPackage(deleteAckPkg);

        vm.startPrank(CROSS_CHAIN);
        vm.expectEmit(true, true, true, true, address(bucketToken));
        emit Transfer(msg.sender, address(0), id);
        bucketHub.handleAckPackage(BUCKET_CHANNEL_ID, msgBytes);
    }

    function _encodeGovSynPackage(ParamChangePackage memory proposal) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](3);
        elements[0] = bytes(proposal.key).encodeBytes();
        elements[1] = proposal.values.encodeBytes();
        elements[2] = proposal.targets.encodeBytes();
        return elements.encodeList();
    }

    function _encodeMirrorSynPackage(CmnMirrorSynPackage memory synPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](3);
        elements[0] = synPkg.id.encodeUint();
        elements[1] = synPkg.key.encodeBytes();
        elements[2] = synPkg.owner.encodeAddress();
        return _RLPEncode(TYPE_MIRROR, elements.encodeList());
    }

    function _encodeCreateAckPackage(CmnCreateAckPackage memory ackPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](3);
        elements[0] = ackPkg.status.encodeUint();
        elements[1] = ackPkg.creator.encodeAddress();
        elements[2] = ackPkg.id.encodeUint();
        return _RLPEncode(TYPE_CREATE, elements.encodeList());
    }

    function _encodeDeleteAckPackage(CmnDeleteAckPackage memory ackPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](2);
        elements[0] = ackPkg.status.encodeUint();
        elements[1] = ackPkg.id.encodeUint();
        return _RLPEncode(TYPE_DELETE, elements.encodeList());
    }
}
