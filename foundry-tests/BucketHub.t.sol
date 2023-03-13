// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../contracts/CrossChain.sol";
import "../contracts/middle-layer/BucketHub.sol";
import "../contracts/middle-layer/GovHub.sol";
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
    event ReceivedAckPkg(uint8 channelId, bytes msgData, bytes callbackData);
    event ReceivedFailAckPkg(uint8 channelId, bytes msgData, bytes callbackData);

    ERC721NonTransferable public bucketToken;
    BucketHub public bucketHub;
    GovHub public govHub;
    CrossChain public crossChain;

    receive() external payable {}

    function setUp() public {
        vm.createSelectFork("test");

        govHub = GovHub(GOV_HUB);
        crossChain = CrossChain(CROSS_CHAIN);
        bucketHub = BucketHub(BUCKET_HUB);
        bucketToken = ERC721NonTransferable(bucketHub.ERC721Token());

        vm.label(GOV_HUB, "govHub");
        vm.label(BUCKET_HUB, "bucketHub");
        vm.label(CROSS_CHAIN, "crossChain");
        vm.label(address(bucketToken), "bucketToken");

        bucketHub.setFailureHandleStrategy(FailureHandleStrategy.NoCallback);
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
            readQuota: 0,
            extraData: ""
        });

        vm.expectEmit(true, true, true, true, address(bucketHub));
        emit CreateSubmitted(address(this), address(this), "test", 2e15, 2e15);
        bucketHub.createBucket{value: 41e14}(synPkg, address(this), "");

        bytes memory msgBytes =
            _encodeCreateAckPackage(0, id, address(this), address(this), FailureHandleStrategy.NoCallback);

        uint64 sequence = crossChain.channelReceiveSequenceMap(BUCKET_CHANNEL_ID);
        vm.expectEmit(true, true, true, true, address(bucketToken));
        emit Transfer(address(0), address(this), id);
        vm.prank(CROSS_CHAIN);
        bucketHub.handleAckPackage(BUCKET_CHANNEL_ID, sequence, msgBytes);
    }

    function testDelete(uint256 id) public {
        vm.prank(BUCKET_HUB);
        bucketToken.mint(address(this), id);
        assertEq(address(this), bucketToken.ownerOf(id));

        vm.expectEmit(true, true, true, true, address(bucketHub));
        emit DeleteSubmitted(address(this), address(this), id, 2e15, 2e15);
        bucketHub.deleteBucket{value: 41e14}(id, address(this), "");

        bytes memory msgBytes = _encodeDeleteAckPackage(0, id, address(this), FailureHandleStrategy.NoCallback);

        uint64 sequence = crossChain.channelReceiveSequenceMap(BUCKET_CHANNEL_ID);
        vm.startPrank(CROSS_CHAIN);
        vm.expectEmit(true, true, true, true, address(bucketToken));
        emit Transfer(address(this), address(0), id);
        bucketHub.handleAckPackage(BUCKET_CHANNEL_ID, sequence, msgBytes);
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
            readQuota: 0,
            extraData: ""
        });

        // failed without authorization
        vm.expectRevert(bytes("no permission to create"));
        bucketHub.createBucket{value: 41e14}(synPkg, address(this), "");

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
        emit CreateSubmitted(granter, operator, "test1", 2e15, 2e15);
        bucketHub.createBucket{value: 41e14}(synPkg, address(this), "");

        // delete success
        uint256 tokenId = 0;
        vm.prank(BUCKET_HUB);
        bucketToken.mint(granter, tokenId);

        vm.expectEmit(true, true, true, true, address(bucketHub));
        emit DeleteSubmitted(granter, operator, tokenId, 2e15, 2e15);
        bucketHub.deleteBucket{value: 41e14}(tokenId, address(this), "");

        // grant expire
        vm.warp(expireTime + 1);
        synPkg.name = "test2";
        vm.expectRevert(bytes("no permission to create"));
        bucketHub.createBucket{value: 41e14}(synPkg, address(this), "");

        // revoke and create failed
        expireTime = block.timestamp + 1 days;
        vm.prank(msg.sender);
        bucketHub.grant(operator, AUTH_CODE_CREATE, expireTime);
        bucketHub.createBucket{value: 41e14}(synPkg, address(this), "");

        vm.prank(msg.sender);
        bucketHub.revoke(operator, AUTH_CODE_CREATE);

        synPkg.name = "test3";
        vm.expectRevert(bytes("no permission to create"));
        bucketHub.createBucket{value: 41e14}(synPkg, address(this), "");
    }

    function testCallback() public {
        // app closed
        bucketHub.setFailureHandleStrategy(FailureHandleStrategy.Closed);
        vm.expectRevert(bytes("application closed"));
        bucketHub.deleteBucket{value: 41e14}(0, address(this), "");

        // hand in order
        bucketHub.setFailureHandleStrategy(FailureHandleStrategy.HandleInSequence);

        CreateSynPackage memory synPkg = CreateSynPackage({
            creator: address(this),
            name: "test",
            isPublic: true,
            paymentAddress: address(this),
            primarySpAddress: address(this),
            primarySpApprovalExpiredHeight: 0,
            primarySpSignature: "",
            readQuota: 0,
            extraData: ""
        });

        bucketHub.createBucket{value: 41e14}(synPkg, address(this), "");
        bytes memory msgBytes =
            _encodeCreateAckPackage(0, 0, address(this), address(this), FailureHandleStrategy.HandleInSequence);

        uint64 sequence = crossChain.channelReceiveSequenceMap(BUCKET_CHANNEL_ID);
        vm.expectEmit(true, true, true, true, address(this));
        emit ReceivedAckPkg(BUCKET_CHANNEL_ID, msgBytes, "");
        vm.prank(CROSS_CHAIN);
        bucketHub.handleAckPackage(BUCKET_CHANNEL_ID, sequence, msgBytes);
    }

    function testFailAck() public {
        bucketHub.setFailureHandleStrategy(FailureHandleStrategy.HandleInSequence);

        CreateSynPackage memory synPkg = CreateSynPackage({
            creator: address(this),
            name: "test",
            isPublic: true,
            paymentAddress: address(this),
            primarySpAddress: address(this),
            primarySpApprovalExpiredHeight: 0,
            primarySpSignature: "",
            readQuota: 0,
            extraData: ""
        });

        bucketHub.createBucket{value: 41e14}(synPkg, address(this), "");
        bytes memory msgBytes =
            _encodeCreateAckPackage(0, 0, address(this), address(this), FailureHandleStrategy.HandleInSequence);

        uint64 sequence = crossChain.channelReceiveSequenceMap(BUCKET_CHANNEL_ID);
        vm.expectEmit(true, true, true, true, address(this));
        emit ReceivedFailAckPkg(BUCKET_CHANNEL_ID, msgBytes, "");
        vm.prank(CROSS_CHAIN);
        bucketHub.handleFailAckPackage(BUCKET_CHANNEL_ID, sequence, msgBytes);
    }

    /*----------------- middle-layer app function -----------------*/
    // override the function in BucketHub
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
        bytes[] memory elements = new bytes[](32);
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
}
