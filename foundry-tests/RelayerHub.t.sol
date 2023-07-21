// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/RelayerHub.sol";

contract RelayerHubTest is Test, RelayerHub {
    address private developer = 0x0000000000000000000000000000000012345678;
    address private user1 = 0x1000000000000000000000000000000012345679;

    RelayerHub private relayerHub;

    function setUp() public {
        vm.createSelectFork("local");
        vm.deal(developer, 10000 ether);
        vm.deal(TOKEN_HUB, 10000 ether);

        relayerHub = RelayerHub(payable(RELAYER_HUB));
        vm.label(RELAYER_HUB, "RELAYER_HUB");

        vm.deal(TOKEN_HUB, 10000 ether);
    }

    function test_add_relayer_fee_correct_case() public {
        vm.expectEmit(true, true, true, true, RELAYER_HUB);
        emit RewardToRelayer(developer, 1 ether);

        vm.prank(CROSS_CHAIN);
        relayerHub.addReward(developer, 1 ether);
    }

    function test_add_relayer_fee_error_case() public {
        vm.expectEmit(true, true, true, true, RELAYER_HUB);
        emit RewardToRelayer(developer, 0);

        vm.prank(CROSS_CHAIN);
        relayerHub.addReward(developer, 2 ether);
    }
}
