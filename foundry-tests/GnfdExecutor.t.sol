// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "contracts/CrossChain.sol";
import "../contracts/middle-layer/GreenfieldExecutor.sol";

contract GnfdExecutorTest is Test, GreenfieldExecutor {
    event CrossChainPackage(
        uint32 srcChainId,
        uint32 dstChainId,
        uint64 indexed oracleSequence,
        uint64 indexed packageSequence,
        uint8 indexed channelId,
        bytes payload
    );

    GreenfieldExecutor public gnfdExecutor;
    CrossChain public crossChain;

    function setUp() public {
        vm.createSelectFork("local");

        crossChain = CrossChain(CROSS_CHAIN);
        gnfdExecutor = GreenfieldExecutor(GNFD_EXECUTOR);

        vm.label(CROSS_CHAIN, "crossChain");
        vm.label(GNFD_EXECUTOR, "gnfdExecutor");
    }

    function testExecute() public {
        uint8[] memory msgTypes = new uint8[](1);
        bytes[] memory msgBytes = new bytes[](1);
        msgTypes[0] = 1;
        msgBytes[0] = hex"0a2a307866333946643665353161616438384636463463653661423838323732373963666646623932323636";

        vm.expectEmit(false, false, true, false, address(crossChain));
        emit CrossChainPackage(0, 0, 0, 0, GNFD_EXECUTOR_CHANNEL_ID, hex"");
        gnfdExecutor.execute(msgTypes, msgBytes);
    }
}
