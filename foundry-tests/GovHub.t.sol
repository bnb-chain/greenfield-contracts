// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "contracts/CrossChain.sol";
import "contracts/middle-layer/GovHub.sol";
import "contracts/middle-layer/resource-mirror/BucketHub.sol";
import "contracts/tokens/ERC721NonTransferable.sol";
import "../contracts/test/GnfdLightClientTest.sol";

contract GovHubTest is Test, GovHub {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event GreenfieldCall(
        uint32 indexed status,
        uint8 channelId,
        uint8 indexed operationType,
        uint256 indexed resourceId,
        bytes callbackData
    );

    ERC721NonTransferable public bucketToken;
    GovHub public govHub;
    CrossChain public crossChain;

    receive() external payable {}

    function setUp() public {
        vm.createSelectFork("local");

        govHub = GovHub(GOV_HUB);
        crossChain = CrossChain(CROSS_CHAIN);

        vm.label(GOV_HUB, "govHub");
        vm.label(CROSS_CHAIN, "crossChain");
    }

    function test_gov_correct_case_1() public {
        ParamChangePackage memory proposal = ParamChangePackage({
            key: "BaseURI",
            values: bytes("newBucket"),
            targets: abi.encodePacked(BUCKET_HUB)
        });
        bytes memory msgBytes = _encodeGovSynPackage(proposal);

        vm.expectEmit(true, true, false, true, BUCKET_HUB);
        emit ParamChange("BaseURI", bytes("newBucket"));
        vm.prank(CROSS_CHAIN);
        govHub.handleSynPackage(GOV_CHANNEL_ID, msgBytes);
    }

    function test_gov_correct_case_2() public {
        ParamChangePackage memory proposal = ParamChangePackage({
            key: "BaseURI",
            values: bytes("newBucket"),
            targets: abi.encodePacked(BUCKET_HUB)
        });

        vm.expectEmit(true, true, false, true, BUCKET_HUB);
        emit ParamChange("BaseURI", bytes("newBucket"));
        vm.prank(EMERGENCY_UPGRADE_OPERATOR);
        govHub.emergencyUpdate(proposal.key, proposal.values, proposal.targets);
    }

    function test_gov_correct_case_3() public {
        address _newLightClient = address(new GnfdLightClientTest());
        ParamChangePackage memory proposal = ParamChangePackage({
            key: "upgrade",
            values: abi.encodePacked(_newLightClient),
            targets: abi.encodePacked(LIGHT_CLIENT)
        });

        vm.expectEmit(true, true, true, true, GOV_HUB);
        emit SuccessUpgrade(LIGHT_CLIENT, _newLightClient);
        vm.prank(EMERGENCY_UPGRADE_OPERATOR);
        govHub.emergencyUpdate(proposal.key, proposal.values, proposal.targets);
    }

    function test_gov_error_case_1() public {
        ParamChangePackage memory proposal = ParamChangePackage({
            key: "BaseURI",
            values: bytes("newBucket"),
            targets: abi.encodePacked(BUCKET_HUB)
        });

        vm.expectRevert("only Emergency Upgrade Operator");
        govHub.emergencyUpdate(proposal.key, proposal.values, proposal.targets);
    }

    function _encodeGovSynPackage(ParamChangePackage memory proposal) internal pure returns (bytes memory) {
        return abi.encode(proposal);
    }

}
