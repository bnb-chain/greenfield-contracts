// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "contracts/CrossChain.sol";
import "contracts/middle-layer/GovHub.sol";
import "contracts/middle-layer/resource-mirror/BucketHub.sol";
import "contracts/tokens/ERC721NonTransferable.sol";

contract BucketHubTest is Test, BucketHub {
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

    ERC721NonTransferable public bucketToken;
    BucketHub public bucketHub;
    GovHub public govHub;
    CrossChain public crossChain;

    receive() external payable {}

    function setUp() public {
        vm.createSelectFork("local");

        govHub = GovHub(GOV_HUB);
        crossChain = CrossChain(CROSS_CHAIN);
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
        CmnMirrorSynPackage memory mirrorSynPkg = CmnMirrorSynPackage({ id: id, owner: address(this) });
        bytes memory msgBytes = _encodeMirrorSynPackage(mirrorSynPkg);

        vm.expectEmit(true, true, true, true, address(bucketToken));
        emit Transfer(address(0), address(this), id);
        vm.prank(CROSS_CHAIN);
        bucketHub.handleSynPackage(BUCKET_CHANNEL_ID, msgBytes);
    }

    function testCreate(uint256 id) public {
        CreateBucketSynPackage memory synPkg = CreateBucketSynPackage({
            creator: address(this),
            name: "test",
            visibility: BucketVisibilityType.PublicRead,
            paymentAddress: address(this),
            primarySpAddress: address(this),
            primarySpApprovalExpiredHeight: 0,
            primarySpSignature: "",
            chargedReadQuota: 0,
            extraData: ""
        });

        vm.expectEmit(true, true, true, true, address(bucketHub));
        emit CreateSubmitted(address(this), address(this), "test");
        bucketHub.createBucket{ value: 4e15 }(synPkg);

        bytes memory msgBytes = _encodeCreateAckPackage(0, id, address(this));

        uint64 sequence = crossChain.channelReceiveSequenceMap(BUCKET_CHANNEL_ID);
        vm.expectEmit(true, true, true, true, address(bucketToken));
        emit Transfer(address(0), address(this), id);
        vm.prank(CROSS_CHAIN);
        bucketHub.handleAckPackage(BUCKET_CHANNEL_ID, sequence, msgBytes, 0);
    }

    function testDelete(uint256 id) public {
        vm.prank(BUCKET_HUB);
        bucketToken.mint(address(this), id);
        assertEq(address(this), bucketToken.ownerOf(id));

        vm.expectEmit(true, true, true, true, address(bucketHub));
        emit DeleteSubmitted(address(this), address(this), id);
        bucketHub.deleteBucket{ value: 4e15 }(id);

        bytes memory msgBytes = _encodeDeleteAckPackage(0, id);

        uint64 sequence = crossChain.channelReceiveSequenceMap(BUCKET_CHANNEL_ID);
        vm.startPrank(CROSS_CHAIN);
        vm.expectEmit(true, true, true, true, address(bucketToken));
        emit Transfer(address(this), address(0), id);
        bucketHub.handleAckPackage(BUCKET_CHANNEL_ID, sequence, msgBytes, 0);
    }

    function testGrantAndRevoke() public {
        address granter = msg.sender;
        address operator = address(this);

        CreateBucketSynPackage memory synPkg = CreateBucketSynPackage({
            creator: granter,
            name: "test1",
            visibility: BucketVisibilityType.PublicRead,
            paymentAddress: address(this),
            primarySpAddress: address(this),
            primarySpApprovalExpiredHeight: 0,
            primarySpSignature: "",
            chargedReadQuota: 0,
            extraData: ""
        });

        // failed without authorization
        vm.expectRevert(bytes("no permission to create"));
        bucketHub.createBucket{ value: 4e15 }(synPkg);

        // wrong auth code
        uint256 expireTime = block.timestamp + 1 days;
        uint32 authCode = 7;
        vm.expectRevert(bytes("invalid authorization code"));
        vm.prank(msg.sender);
        bucketHub.grant(operator, authCode, expireTime);

        // grant
        authCode = 3; // create and delete
        vm.prank(msg.sender);
        bucketHub.grant(operator, authCode, expireTime);

        // create success
        vm.expectEmit(true, true, true, true, address(bucketHub));
        emit CreateSubmitted(granter, operator, "test1");
        bucketHub.createBucket{ value: 4e15 }(synPkg);

        // delete success
        uint256 tokenId = 0;
        vm.prank(BUCKET_HUB);
        bucketToken.mint(granter, tokenId);

        vm.expectEmit(true, true, true, true, address(bucketHub));
        emit DeleteSubmitted(granter, operator, tokenId);
        bucketHub.deleteBucket{ value: 4e15 }(tokenId);

        // grant expire
        vm.warp(expireTime + 1);
        synPkg.name = "test2";
        vm.expectRevert(bytes("no permission to create"));
        bucketHub.createBucket{ value: 4e15 }(synPkg);

        // revoke and create failed
        expireTime = block.timestamp + 1 days;
        vm.prank(msg.sender);
        bucketHub.grant(operator, AUTH_CODE_CREATE, expireTime);
        bucketHub.createBucket{ value: 4e15 }(synPkg);

        vm.prank(msg.sender);
        bucketHub.revoke(operator, AUTH_CODE_CREATE);

        synPkg.name = "test3";
        vm.expectRevert(bytes("no permission to create"));
        bucketHub.createBucket{ value: 4e15 }(synPkg);
    }

    function testCallback(uint256 tokenId) public {
        bytes memory msgBytes = _encodeCreateAckPackage(
            STATUS_SUCCESS,
            tokenId,
            address(this),
            address(this),
            FailureHandleStrategy.BlockOnFail
        );
        uint64 sequence = crossChain.channelReceiveSequenceMap(BUCKET_CHANNEL_ID);

        vm.expectEmit(true, true, true, false, address(this));
        emit GreenfieldCall(STATUS_SUCCESS, BUCKET_CHANNEL_ID, TYPE_CREATE, tokenId, "");
        vm.prank(CROSS_CHAIN);
        bucketHub.handleAckPackage(BUCKET_CHANNEL_ID, sequence, msgBytes, 5000);
    }

    function testFAck() public {
        ExtraData memory extraData = ExtraData({
            appAddress: address(this),
            refundAddress: address(this),
            failureHandleStrategy: FailureHandleStrategy.BlockOnFail,
            callbackData: ""
        });
        CreateBucketSynPackage memory synPkg = CreateBucketSynPackage({
            creator: address(this),
            name: "test",
            visibility: BucketVisibilityType.PublicRead,
            paymentAddress: address(this),
            primarySpAddress: address(this),
            primarySpApprovalExpiredHeight: 0,
            primarySpSignature: "",
            chargedReadQuota: 0,
            extraData: abi.encode(extraData)
        });
        bytes memory msgBytes = abi.encodePacked(TYPE_CREATE, abi.encode(synPkg));
        uint64 sequence = crossChain.channelReceiveSequenceMap(BUCKET_CHANNEL_ID);

        vm.expectEmit(true, true, true, false, address(this));
        emit GreenfieldCall(STATUS_UNEXPECTED, BUCKET_CHANNEL_ID, TYPE_CREATE, 0, "");
        vm.prank(CROSS_CHAIN);
        bucketHub.handleFailAckPackage(BUCKET_CHANNEL_ID, sequence, msgBytes, 5000);
    }

    function testRetryPkg() public {
        // callback failed(out of gas)
        bytes memory msgBytes = _encodeCreateAckPackage(
            1,
            0,
            address(this),
            address(this),
            FailureHandleStrategy.BlockOnFail
        );
        uint64 sequence = crossChain.channelReceiveSequenceMap(BUCKET_CHANNEL_ID);

        vm.expectEmit(true, false, false, false, address(bucketHub));
        emit AppHandleAckPkgFailed(address(this), bytes32(""), "");
        vm.prank(CROSS_CHAIN);
        bucketHub.handleAckPackage(BUCKET_CHANNEL_ID, sequence, msgBytes, 3000);

        // block on fail
        ExtraData memory extraData = ExtraData({
            appAddress: address(this),
            refundAddress: address(this),
            failureHandleStrategy: FailureHandleStrategy.BlockOnFail,
            callbackData: ""
        });
        CreateBucketSynPackage memory synPkg = CreateBucketSynPackage({
            creator: address(this),
            name: "test",
            visibility: BucketVisibilityType.PublicRead,
            paymentAddress: address(this),
            primarySpAddress: address(this),
            primarySpApprovalExpiredHeight: 0,
            primarySpSignature: "",
            chargedReadQuota: 0,
            extraData: ""
        });

        vm.expectRevert(bytes("retry queue is not empty"));
        bucketHub.createBucket{ value: 4e15 }(synPkg, 5000, extraData);

        // retry pkg
        bucketHub.retryPackage();
        bucketHub.createBucket{ value: 4e15 }(synPkg, 5000, extraData);

        // skip on fail
        msgBytes = _encodeCreateAckPackage(1, 0, address(this), address(this), FailureHandleStrategy.SkipOnFail);
        sequence = crossChain.channelReceiveSequenceMap(BUCKET_CHANNEL_ID);

        vm.expectEmit(true, false, false, false, address(bucketHub));
        emit AppHandleAckPkgFailed(address(this), bytes32(""), "");
        vm.prank(CROSS_CHAIN);
        bucketHub.handleAckPackage(BUCKET_CHANNEL_ID, sequence, msgBytes, 3000);

        vm.expectRevert(bytes(hex"3db2a12a")); // "Empty()"
        bucketHub.retryPackage();
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

    function _encodeMirrorSynPackage(CmnMirrorSynPackage memory synPkg) internal pure returns (bytes memory) {
        return abi.encodePacked(TYPE_MIRROR, abi.encode(synPkg));
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
