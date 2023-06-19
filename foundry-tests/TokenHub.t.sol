// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "contracts/CrossChain.sol";
import "contracts/GnfdProxy.sol";
import "contracts/GnfdProxyAdmin.sol";
import "contracts/GnfdLightClient.sol";
import "contracts/middle-layer/GovHub.sol";
import "contracts/middle-layer/TokenHub.sol";

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
    address private user1 = 0x1000000000000000000000000000000012345678;

    CrossChain private crossChain;
    TokenHub private tokenHub;

    function setUp() public {
        vm.createSelectFork("bsc-test");
        vm.deal(developer, 1000 ether);

        crossChain = CrossChain(payable(CROSS_CHAIN));
        tokenHub = TokenHub(payable(TOKEN_HUB));
    }

    function test_transferOut() public {

        uint256 gasBefore = gasleft();
        tokenHub.transferOut{ value: 1e18 + 5e14 }(developer, 1 ether);
        console.log('transferOut gasUsed', gasBefore - gasleft());
    }

    function test_transferOutV2() public {
        TokenHub TokenHub = new TokenHub();
        vm.prank(PROXY_ADMIN);
        GnfdProxy(payable(TOKEN_HUB)).upgradeTo(address(TokenHub));

        uint256 gasBefore = gasleft();
        tokenHub.transferOut{ value: 1e18 + 5e14 }(developer, 1 ether);
        console.log('transferOutV2 gasUsed', gasBefore - gasleft());
    }

    function test_decode_transferInRefund() public {
        uint256 refundAmount = 1 ether;
        address refundAddr = developer;
        uint32 status = 0;
        TransferInRefundPackage memory transInAckPkg = TransferInRefundPackage(refundAmount, refundAddr, status);
        bytes memory msgBytes = _encodeTransferInRefundPackage(transInAckPkg);

        uint256 gasBefore = gasleft();
        (TransferOutAckPackage memory transferOutAckPkg, bool success) = _decodeTransferOutAckPackage(msgBytes);
        console.log('_decodeTransferOutAckPackage gasUsed', gasBefore - gasleft());
    }

    function test_decode_transferInRefundV2() public {
        uint256 refundAmount = 1 ether;
        address refundAddr = developer;
        uint32 status = 0;
        TransferInRefundPackage memory transInAckPkg = TransferInRefundPackage(refundAmount, refundAddr, status);
        bytes memory msgBytes = abi.encode(transInAckPkg);

        uint256 gasBefore = gasleft();
        (TransferOutAckPackage memory transferOutAckPkg) = abi.decode(msgBytes, (TransferOutAckPackage));
        console.log('_decodeTransferOutAckPackage V2 gasUsed', gasBefore - gasleft());
    }

    function test_rlp_fuzzy_test_case_1(uint256 amount, address recipient, address refundAddr) public {
        TransferOutSynPackage memory transOutSynPkg = TransferOutSynPackage(amount, recipient, refundAddr);
        bytes memory msgBytes = _encodeTransferOutSynPackage(transOutSynPkg);

        (TransferInSynPackage memory transInSynPkg, bool success) = _decodeTransferInSynPackage(msgBytes);

        assertEq(success, true, "decode transInSynPkg failed");
        assertEq(amount, transInSynPkg.amount);
        assertEq(recipient, transInSynPkg.recipient);
        assertEq(refundAddr, transInSynPkg.refundAddr);
    }

    function test_rlp_fuzzy_test_case_1_abi_decode(uint256 amount, address recipient, address refundAddr) public {
        TransferOutSynPackage memory transOutSynPkg = TransferOutSynPackage(amount, recipient, refundAddr);
        bytes memory msgBytes = abi.encode(transOutSynPkg);
        (TransferInSynPackage memory transInSynPkg) = abi.decode(msgBytes, (TransferInSynPackage));

        assertEq(amount, transInSynPkg.amount);
        assertEq(recipient, transInSynPkg.recipient);
        assertEq(refundAddr, transInSynPkg.refundAddr);
    }

    function test_rlp_fuzzy_test_case_2(uint256 refundAmount, address refundAddr, uint32 status) public {
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

    function test_rlp_fuzzy_test_case_2_abi_decode(uint256 refundAmount, address refundAddr, uint32 status) public {
        TransferInRefundPackage memory transInAckPkg = TransferInRefundPackage(refundAmount, refundAddr, status);
        bytes memory msgBytes = abi.encode(transInAckPkg);

        uint256 gasBefore = gasleft();
        (TransferOutAckPackage memory transferOutAckPkg) = abi.decode(msgBytes, (TransferOutAckPackage));
        console.log('_decodeTransferOutAckPackage V2 gasUsed', gasBefore - gasleft());

        assertEq(refundAmount, transInAckPkg.refundAmount);
        assertEq(refundAddr, transInAckPkg.refundAddr);
        assertEq(status, transInAckPkg.status);

        assertEq(refundAmount, transferOutAckPkg.refundAmount);
        assertEq(refundAddr, transferOutAckPkg.refundAddr);
        assertEq(status, transferOutAckPkg.status);
    }
}
