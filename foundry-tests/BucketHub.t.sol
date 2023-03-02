// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../contracts/middle-layer/GovHub.sol";
import "../contracts/middle-layer/BucketHub.sol";
import "../contracts/tokens/ERC721NonTransferable.sol";

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
        vm.label(CROSS_CHAIN, "crossChain");
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
        CmnMirrorSynPackage memory mirrorSynPkg = CmnMirrorSynPackage({id: id, owner: address(this)});
        bytes memory msgBytes = _encodeMirrorSynPackage(mirrorSynPkg);

        vm.expectEmit(true, true, true, true, address(bucketToken));
        emit Transfer(address(0), address(this), id);
        vm.prank(CROSS_CHAIN);
        bucketHub.handleSynPackage(BUCKET_CHANNEL_ID, msgBytes);
    }

    function testCreate(uint256 id) public {
        CreateSynPackage memory synPkg = CreateSynPackage({
            creator: address(this),
            name: "test",
            isPublic: true,
            paymentAddress: address(this),
            primarySpAddress: address(this),
            primarySpApprovalExpiredHeight: 0,
            primarySpSignature: "",
            readQuota: 0
        });

        vm.expectEmit(true, true, true, true, address(bucketHub));
        emit CreateSubmitted(address(this), address(this), "test", 2e15, 2e15);
        bucketHub.createBucket{value: 4e15}(synPkg);

        CmnCreateAckPackage memory createAckPkg = CmnCreateAckPackage({status: 0, creator: address(this), id: id});
        bytes memory msgBytes = _encodeCreateAckPackage(createAckPkg);

        vm.expectEmit(true, true, true, true, address(bucketToken));
        emit Transfer(address(0), address(this), id);
        vm.prank(CROSS_CHAIN);
        bucketHub.handleAckPackage(BUCKET_CHANNEL_ID, msgBytes);
    }

    function testDelete(uint256 id) public {
        vm.prank(BUCKET_HUB);
        bucketToken.mint(address(this), id);
        assertEq(address(this), bucketToken.ownerOf(id));

        vm.expectEmit(true, true, true, true, address(bucketHub));
        emit DeleteSubmitted(address(this), address(this), id, 2e15, 2e15);
        bucketHub.deleteBucket{value: 4e15}(id);

        CmnDeleteAckPackage memory deleteAckPkg = CmnDeleteAckPackage({status: 0, id: id});
        bytes memory msgBytes = _encodeDeleteAckPackage(deleteAckPkg);

        vm.startPrank(CROSS_CHAIN);
        vm.expectEmit(true, true, true, true, address(bucketToken));
        emit Transfer(address(this), address(0), id);
        bucketHub.handleAckPackage(BUCKET_CHANNEL_ID, msgBytes);
    }

    function testGrantAndRevoke() public {
        address granter = msg.sender;
        address operator = address(this);

        CreateSynPackage memory synPkg = CreateSynPackage({
            creator: granter,
            name: "test1",
            isPublic: true,
            paymentAddress: address(this),
            primarySpAddress: address(this),
            primarySpApprovalExpiredHeight: 0,
            primarySpSignature: "",
            readQuota: 0
        });

        // failed without authorization
        vm.expectRevert(bytes("no permission to create"));
        bucketHub.createBucket{value: 4e15}(synPkg);

        // wrong auth code
        uint256 expireTime = block.timestamp + 1 days;
        uint32 authCode = 0x00001110;
        vm.expectRevert(bytes("invalid authorization code"));
        vm.prank(msg.sender);
        bucketHub.grant(operator, authCode, expireTime);

        // grant
        authCode = 0x00000110; // create and delete
        vm.prank(msg.sender);
        bucketHub.grant(operator, authCode, expireTime);

        // create success
        vm.expectEmit(true, true, true, true, address(bucketHub));
        emit CreateSubmitted(granter, operator, "test1", 2e15, 2e15);
        bucketHub.createBucket{value: 4e15}(synPkg);

        // delete success
        uint256 tokenId = 0;
        vm.prank(BUCKET_HUB);
        bucketToken.mint(granter, tokenId);

        vm.expectEmit(true, true, true, true, address(bucketHub));
        emit DeleteSubmitted(granter, operator, tokenId, 2e15, 2e15);
        bucketHub.deleteBucket{value: 4e15}(tokenId);

        // grant expire
        vm.warp(expireTime + 1);
        synPkg.name = "test2";
        vm.expectRevert(bytes("no permission to create"));
        bucketHub.createBucket{value: 4e15}(synPkg);

        // revoke and create failed
        expireTime = block.timestamp + 1 days;
        vm.prank(msg.sender);
        bucketHub.grant(operator, AUTH_CODE_CREATE, expireTime);
        bucketHub.createBucket{value: 4e15}(synPkg);

        vm.prank(msg.sender);
        bucketHub.revoke(operator, AUTH_CODE_CREATE);

        synPkg.name = "test3";
        vm.expectRevert(bytes("no permission to create"));
        bucketHub.createBucket{value: 4e15}(synPkg);
    }

    function _encodeGovSynPackage(ParamChangePackage memory proposal) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](3);
        elements[0] = bytes(proposal.key).encodeBytes();
        elements[1] = proposal.values.encodeBytes();
        elements[2] = proposal.targets.encodeBytes();
        return elements.encodeList();
    }

    function _encodeMirrorSynPackage(CmnMirrorSynPackage memory synPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](32);
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
}
