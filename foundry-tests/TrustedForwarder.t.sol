// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "contracts/CrossChain.sol";
import "contracts/middle-layer/GovHub.sol";
import "contracts/middle-layer/resource-mirror/MultiMessage.sol";
import "contracts/middle-layer/resource-mirror/AdditionalBucketHub.sol";
import "contracts/middle-layer/resource-mirror/GroupHub.sol";
import "contracts/tokens/ERC721NonTransferable.sol";
import "../contracts/middle-layer/resource-mirror/BucketHub.sol";
import "../contracts/middle-layer/TokenHub.sol";
import "../contracts/interface/ITrustedForwarder.sol";
import "../contracts/middle-layer/resource-mirror/PermissionHub.sol";

contract TrustedForwarderTest is Test, MultiMessage {
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
    event TransferOutSuccess(address senderAddress, uint256 amount, uint256 relayFee, uint256 ackRelayFee);

    ERC721NonTransferable public permissionToken;
    MultiMessage public multiMessage;
    GovHub public govHub;
    GroupHub public groupHub;
    BucketHub public bucketHub;
    PermissionHub public permissionHub;
    CrossChain public crossChain;
    TokenHub public tokenHub;
    ITrustedForwarder public forwarder;
    uint256 public totalRelayFee;

    receive() external payable {}

    function setUp() public {
        vm.createSelectFork("local");

        govHub = GovHub(GOV_HUB);
        groupHub = GroupHub(GROUP_HUB);
        bucketHub = BucketHub(BUCKET_HUB);
        permissionHub = PermissionHub(PERMISSION_HUB);
        crossChain = CrossChain(CROSS_CHAIN);
        tokenHub = TokenHub(payable(TOKEN_HUB));
        multiMessage = MultiMessage(MULTI_MESSAGE);
        permissionToken = ERC721NonTransferable(multiMessage.ERC721Token());
        forwarder = ITrustedForwarder(ERC2771_FORWARDER);


        (uint256 relayFee, uint256 minAckRelayFee) = crossChain.getRelayFees();
        totalRelayFee = relayFee + minAckRelayFee;

        vm.label(GOV_HUB, "GOV_HUB");
        vm.label(MULTI_MESSAGE, "MULTI_MESSAGE");
        vm.label(CROSS_CHAIN, "CROSS_CHAIN");
        vm.label(GROUP_HUB, "GROUP_HUB");
        vm.label(BUCKET_HUB, "BUCKET_HUB");
        vm.label(PERMISSION_HUB, "PERMISSION_HUB");
        vm.label(TOKEN_HUB, "TOKEN_HUB");
        vm.label(ERC2771_FORWARDER, "ERC2771_FORWARDER");

        vm.deal(address(this), 10000 ether);
    }

    function testTrustedForwarder_case1() public {
        address expectSender = address(this);
        address wrongSender = ERC2771_FORWARDER;
        (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        ) = forwarder.eip712Domain();
        console.log("forwarder.name", name);

        uint256 totalValue = 0;
        ITrustedForwarder.Call3Value[] memory calls = new ITrustedForwarder.Call3Value[](4);
        calls[0] = ITrustedForwarder.Call3Value({
            target: address(groupHub),
            allowFailure: false,
            value: totalRelayFee,
            callData: abi.encodeWithSignature("createGroup(address,string)", expectSender, "test1")
        });
        totalValue += calls[0].value;

        uint256 transferOutAmt = 1 ether;
        calls[1] = ITrustedForwarder.Call3Value({
            target: address(tokenHub),
            allowFailure: false,
            value: totalRelayFee + transferOutAmt,
            callData: abi.encodeWithSignature("transferOut(address,uint256)", expectSender, transferOutAmt)
        });
        totalValue += calls[1].value;

        calls[2] = ITrustedForwarder.Call3Value({
            target: address(permissionHub),
            allowFailure: false,
            value: totalRelayFee,
            callData: abi.encodeWithSignature("createPolicy(bytes)", hex'1234')
        });
        totalValue += calls[2].value;

        calls[3] = ITrustedForwarder.Call3Value({
            target: address(groupHub),
            allowFailure: true,
            value: totalRelayFee,
            callData: abi.encodeWithSignature("createGroup(address,string)", wrongSender, "test2")
        });
        totalValue += calls[3].value;

        vm.expectEmit(true, true, true, false, GROUP_HUB);
        emit CreateSubmitted(expectSender, expectSender, "test1");

        vm.expectEmit(true, true, false, false, TOKEN_HUB);
        emit TransferOutSuccess(expectSender, transferOutAmt, 0, 0);

        vm.expectEmit(true, true, false, false, PERMISSION_HUB);
        emit CreateSubmitted(expectSender, expectSender, string(hex'1234'));


        ITrustedForwarder.Result[] memory res = forwarder.aggregate3Value{ value: totalValue }(calls);
        assertEq(res[0].success && res[1].success && res[2].success && !res[3].success, true, "invalid results");
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
