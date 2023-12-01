// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "contracts/CrossChain.sol";
import "contracts/middle-layer/GovHub.sol";
import "contracts/middle-layer/resource-mirror/PermissionHub.sol";
import "contracts/tokens/ERC721NonTransferable.sol";

contract PermissionHubTest is Test, PermissionHub {
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
    PermissionHub public permissionHub;
    GovHub public govHub;
    CrossChain public crossChain;

    receive() external payable {}

    function setUp() public {
        vm.createSelectFork("local");

        govHub = GovHub(GOV_HUB);
        crossChain = CrossChain(CROSS_CHAIN);
        permissionHub = PermissionHub(PERMISSION_HUB);
        permissionToken = ERC721NonTransferable(permissionHub.ERC721Token());

        vm.label(GOV_HUB, "govHub");
        vm.label(PERMISSION_HUB, "permissionHub");
        vm.label(CROSS_CHAIN, "crossChain");
        vm.label(address(permissionToken), "permissionToken");
    }

    function testBasicInfo() public {
        string memory baseUri = permissionToken.baseURI();
        assertEq(baseUri, "permission");
    }

    function testGov() public {
        ParamChangePackage memory proposal = ParamChangePackage({
            key: "BaseURI",
            values: bytes("newPermission"),
            targets: abi.encodePacked(address(permissionHub))
        });
        bytes memory msgBytes = _encodeGovSynPackage(proposal);

        vm.expectEmit(true, true, false, true, address(permissionHub));
        emit ParamChange("BaseURI", bytes("newPermission"));
        vm.prank(CROSS_CHAIN);
        govHub.handleSynPackage(GOV_CHANNEL_ID, msgBytes);
    }

    function testCreate(uint256 id) public {
        CreatePutPolicySynPackage memory synPkg = CreatePutPolicySynPackage({
            operator: address(this),
            data: "",
            extraData: ""
        });

        vm.expectEmit(true, true, true, true, address(permissionHub));
        emit CreateSubmitted(address(this), address(this), string(synPkg.data));
        permissionHub.createPutPolicy{ value: 4e15 }("");

        bytes memory msgBytes = _encodeCreateAckPackage(0, id, address(this));
        uint64 sequence = crossChain.channelReceiveSequenceMap(PERMISSION_CHANNEL_ID);
        vm.expectEmit(true, true, true, true, address(permissionToken));
        emit Transfer(address(0), address(this), id);
        vm.prank(CROSS_CHAIN);
        permissionHub.handleAckPackage(PERMISSION_CHANNEL_ID, sequence, msgBytes, 0);
    }

    function testDelete(uint256 id) public {
        vm.prank(PERMISSION_HUB);
        permissionToken.mint(address(this), id);
        assertEq(address(this), permissionToken.ownerOf(id));

        vm.expectEmit(true, true, true, true, address(permissionHub));
        emit DeleteSubmitted(address(this), address(this), id);
        permissionHub.deletePolicy{ value: 4e15 }(id);

        bytes memory msgBytes = _encodeDeleteAckPackage(0, id);

        uint64 sequence = crossChain.channelReceiveSequenceMap(PERMISSION_CHANNEL_ID);
        vm.startPrank(CROSS_CHAIN);
        vm.expectEmit(true, true, true, true, address(permissionToken));
        emit Transfer(address(this), address(0), id);
        permissionHub.handleAckPackage(PERMISSION_CHANNEL_ID, sequence, msgBytes, 0);
    }

    function testCallback(uint256 tokenId) public {
        bytes memory msgBytes = _encodeCreateAckPackage(
            STATUS_SUCCESS,
            tokenId,
            address(this),
            address(this),
            FailureHandleStrategy.SkipOnFail
        );
        uint64 sequence = crossChain.channelReceiveSequenceMap(PERMISSION_CHANNEL_ID);

        vm.expectEmit(true, true, true, false, address(this));
        emit GreenfieldCall(STATUS_SUCCESS, PERMISSION_CHANNEL_ID, TYPE_CREATE, tokenId, "");
        vm.prank(CROSS_CHAIN);
        permissionHub.handleAckPackage(PERMISSION_CHANNEL_ID, sequence, msgBytes, 5000);
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
