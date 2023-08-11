// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "contracts/CrossChain.sol";
import "contracts/GnfdProxy.sol";
import "contracts/GnfdProxyAdmin.sol";
import "contracts/GnfdLightClient.sol";
import "contracts/middle-layer/GovHub.sol";
import "contracts/middle-layer/TokenHub.sol";
import "../contracts/RelayerHub.sol";

contract TokenHubTest is Test, TokenHub {
    uint16 public constant gnfdChainId = 1;
    bytes public constant blsPubKeys =
        hex"8ec21505e290d7c15f789c7b4c522179bb7d70171319bfe2d6b2aae2461a1279566782907593cc526a5f2611c0721d60b4a78719a34817cc1d085b6eed110ed1d1ca59a35c9cf4d094e4e71b0b8b76ac2d30ba0762ec9acfaca8b8b369d914e980e970c25a8580cb0d840dce6fff3adc830e16ec8660fb91c8811a28d8ada91d539f82d2730496549e7783a34167498c";
    address[] public relayers = [
        0x1115E495c48bEb783ee04Ca99b7c2F87Faf6F8eb,
        0x56B2404e087F55D6E16bEED3aDee8F51414A301b,
        0xE7B8E0894FF97dd5c846c8A031becDb06E2390ea
    ];

    address private developer = 0x0000000000000000000000000000000012345678;
    address private user1 = 0x1000000000000000000000000000000012345679;

    CrossChain private crossChain;
    TokenHub private tokenHub;
    RelayerHub private relayerHub;

    function setUp() public {
        vm.createSelectFork("local");
        vm.deal(developer, 10000 ether);
        vm.deal(TOKEN_HUB, 10000 ether);

        crossChain = CrossChain(payable(CROSS_CHAIN));
        tokenHub = TokenHub(payable(TOKEN_HUB));
        relayerHub = RelayerHub(payable(RELAYER_HUB));

        vm.label(TOKEN_HUB, "TOKEN_HUB");
        vm.label(CROSS_CHAIN, "CROSS_CHAIN");
        vm.label(RELAYER_HUB, "RELAYER_HUB");
    }

    function test_transferOut_correct_case() public {
        vm.startPrank(developer);
        vm.expectEmit(true, true, true, true, TOKEN_HUB);
        emit TransferOutSuccess(developer, 123 ether, 25 * 1e13, 120 * 1e13);
        tokenHub.transferOut{ value: 123 ether + 145 * 1e13 }(user1, 123 ether);
        vm.stopPrank();
    }

    function test_transferIn_correct_case() public {
        TransferInSynPackage memory pkg = TransferInSynPackage(123 ether, user1, developer);
        bytes memory msgBytes = abi.encode(pkg);

        vm.expectEmit(true, true, true, true, TOKEN_HUB);
        emit TransferInSuccess(user1, 123 ether);
        vm.prank(CROSS_CHAIN);
        tokenHub.handleSynPackage(TRANSFER_IN_CHANNEL_ID, msgBytes);
    }

    function test_transferIn_case_2() public {
        vm.expectRevert("no locked amount");
        tokenHub.withdrawUnlockedToken(user1);

        TransferInSynPackage memory pkg = TransferInSynPackage(1000 ether, user1, developer);
        bytes memory msgBytes = abi.encode(pkg);

        vm.expectEmit(true, true, true, true, TOKEN_HUB);
        emit LargeTransferLocked(user1, 1000 ether, block.timestamp + 12 hours);

        vm.expectEmit(true, true, true, true, TOKEN_HUB);
        emit TransferInSuccess(user1, 1000 ether);

        vm.prank(CROSS_CHAIN);
        tokenHub.handleSynPackage(TRANSFER_IN_CHANNEL_ID, msgBytes);

        vm.expectRevert("still on locking period");
        tokenHub.withdrawUnlockedToken(user1);

        uint256 _current = block.timestamp;
        vm.warp(_current + 11 hours);
        vm.expectRevert("still on locking period");
        tokenHub.withdrawUnlockedToken(user1);

        vm.warp(_current + 12 hours);
        vm.expectEmit(true, true, true, true, TOKEN_HUB);
        emit WithdrawUnlockedToken(user1, 1000 ether);
        tokenHub.withdrawUnlockedToken(user1);
    }

    function test_transferIn_case_3() public {
        vm.expectRevert("no locked amount");
        tokenHub.withdrawUnlockedToken(user1);

        TransferInSynPackage memory pkg = TransferInSynPackage(1000 ether, user1, developer);
        bytes memory msgBytes = abi.encode(pkg);

        vm.expectEmit(true, true, true, true, TOKEN_HUB);
        emit LargeTransferLocked(user1, 1000 ether, block.timestamp + 12 hours);

        vm.expectEmit(true, true, true, true, TOKEN_HUB);
        emit TransferInSuccess(user1, 1000 ether);

        vm.prank(CROSS_CHAIN);
        tokenHub.handleSynPackage(TRANSFER_IN_CHANNEL_ID, msgBytes);

        vm.expectRevert("still on locking period");
        tokenHub.withdrawUnlockedToken(user1);

        vm.startPrank(CROSS_CHAIN);

        vm.expectEmit(true, true, true, true, TOKEN_HUB);
        emit CancelTransfer(user1, 1000 ether);
        tokenHub.cancelTransferIn(user1);

        vm.expectRevert("no locked amount");
        tokenHub.withdrawUnlockedToken(user1);

        vm.stopPrank();
    }

    function test_refund_correct_case() public {
        // CROSS_CHAIN cannot receive BNB transfers since the receive() interface is not implemented by CROSS_CHAIN
        TransferOutAckPackage memory pkg = TransferOutAckPackage(123 ether, developer, 1);
        bytes memory msgBytes = abi.encode(pkg);

        uint256 initBalance = developer.balance;
        vm.expectEmit(true, true, true, true, TOKEN_HUB);
        emit RefundSuccess(developer, 123 ether, 1);
        vm.prank(CROSS_CHAIN);
        tokenHub.handleAckPackage(TRANSFER_OUT_CHANNEL_ID, 1, msgBytes, 0);

        assertEq(developer.balance, initBalance + 123 ether, "invalid refund amount");
    }

    function test_decode_transferInRefund() public view {
        uint256 refundAmount = 1 ether;
        address refundAddr = developer;
        uint32 status = 0;
        TransferInRefundPackage memory transInAckPkg = TransferInRefundPackage(refundAmount, refundAddr, status);
        bytes memory msgBytes = _encodeTransferInRefundPackage(transInAckPkg);

        uint256 gasBefore = gasleft();
        _decodeTransferOutAckPackage(msgBytes);
        console.log('_decodeTransferOutAckPackage gasUsed', gasBefore - gasleft());
    }

    function test_encode_fuzzy_test_case_1(uint256 amount, address recipient, address refundAddr) public {
        TransferOutSynPackage memory transOutSynPkg = TransferOutSynPackage(amount, recipient, refundAddr);
        bytes memory msgBytes = _encodeTransferOutSynPackage(transOutSynPkg);

        (TransferInSynPackage memory transInSynPkg, bool success) = _decodeTransferInSynPackage(msgBytes);

        assertEq(success, true, "decode transInSynPkg failed");
        assertEq(amount, transInSynPkg.amount);
        assertEq(recipient, transInSynPkg.recipient);
        assertEq(refundAddr, transInSynPkg.refundAddr);
    }

    function test_fuzzy_test_case_1_abi_decode(uint256 amount, address recipient, address refundAddr) public {
        TransferOutSynPackage memory transOutSynPkg = TransferOutSynPackage(amount, recipient, refundAddr);
        bytes memory msgBytes = abi.encode(transOutSynPkg);
        (TransferInSynPackage memory transInSynPkg) = abi.decode(msgBytes, (TransferInSynPackage));

        assertEq(amount, transInSynPkg.amount);
        assertEq(recipient, transInSynPkg.recipient);
        assertEq(refundAddr, transInSynPkg.refundAddr);
    }

    function test_fuzzy_test_case_2_abi_encode(uint256 refundAmount, address refundAddr, uint32 status) public {
        TransferInRefundPackage memory transInAckPkg = TransferInRefundPackage(refundAmount, refundAddr, status);
        bytes memory msgBytes = _encodeTransferInRefundPackage(transInAckPkg);

        uint256 gasBefore = gasleft();
        (TransferOutAckPackage memory transferOutAckPkg, bool success) = _decodeTransferOutAckPackage(msgBytes);
        console.log('_decodeTransferOutAckPackage gasUsed', gasBefore - gasleft());

        assertEq(success, true, "decode transferOutAckPkg failed");
        assertEq(refundAmount, transInAckPkg.refundAmount);
        assertEq(refundAddr, transInAckPkg.refundAddr);
        assertEq(status, transInAckPkg.status);

        assertEq(refundAmount, transferOutAckPkg.refundAmount);
        assertEq(refundAddr, transferOutAckPkg.refundAddr);
        assertEq(status, transferOutAckPkg.status);
    }
}
