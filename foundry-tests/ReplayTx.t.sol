// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "contracts/Deployer.sol";
import "contracts/CrossChain.sol";
import "contracts/middle-layer/GovHub.sol";
import "contracts/middle-layer/TokenHub.sol";
import "./Helper.sol";
import "../contracts/GnfdLightClientV2.sol";

abstract contract Network is Test {
    constructor() {
        vm.createSelectFork("bsc-test");
    }
}

contract ReplayTxTest is Network, Helper {
    address private developer = 0x0000000000000000000000000000000012345678;
    address private user1 = 0x1000000000000000000000000000000012345678;

    function replayTx(address relayer, bytes memory data) public {
        address newImplLightClient = address(new GnfdLightClientV2());
        vm.startPrank(deployer.proxyGovHub());
        proxyAdmin.upgrade(TransparentUpgradeableProxy(payable(deployer.proxyLightClient())), newImplLightClient);
        vm.stopPrank();
        vm.deal(developer, 10000 ether);

        vm.startPrank(relayer, relayer);
        (bool success, ) = address(crossChain).call(data);
        require(success, "replayTx failed");
        vm.stopPrank();
    }

    function test_transferIn_handlePackage() public {
        vm.createSelectFork("bsc-test", 30138322);
        address relayer = 0x0dfA99423d3084C596C5E3Bd6BCb4F654516517B;
        bytes memory data = hex"c9978d2400000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000001f00000000000000000000000000000000000000000000000000000000000000892328006101000000000000004200000000006470b63e0000000000000000000000000000000000000000000000000000e35fa931a0000000000000000000000000000000000000000000000000000000000000000000f287038d7ea4c6800094e820c885dd22d6b28c3e2264f67f9dd799ad98d294d510b9b68afabe68a2038deb9fb50f2e9b9e719e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006089f2dc8ee5e55bbd473fa9b8c16ed11328033e61ab46ea03b3454e5d106fc42749030540411d4d93077aaccf7995a4a5001760ac18c1c0acdd7478a6a762fd3dc626325f00895709085af936dc192f768ee0913df5fb4ccec14705a3a2ceefbf";
        replayTx(relayer, data);
    }

    function test_deleteBucket_handlePackage() public {
        vm.createSelectFork("bsc-test", 30096171);
        address relayer = 0x0dfA99423d3084C596C5E3Bd6BCb4F654516517B;
        bytes memory data = hex"c9978d24000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000001f000000000000000000000000000000000000000000000000000000000000003f232800610400000000000000220100000000646ec83f0000000000000000000000000000000000000000000000000000e35fa931a000c80386c58082328580000000000000000000000000000000000000000000000000000000000000000060b7b82fb74eb2c81ecc9813dc6ca55309c92134248f7824afc39ed875006dc5521631210003e4bc2a33d9d9c278227a540de1ea0c7fb77e15d322e56dc71cf7ed53eba2bd4675af1d88d8501a8253553b50944eb9de077b3110d07f95900e1cd3";
        replayTx(relayer, data);
    }

    function test_createBucket_handlePackage() public {
        vm.createSelectFork("bsc-test", 30096156);
        address relayer = 0x668a0aCd8f6Db5CAe959A0E02132f4d6a672C4d7;
        bytes memory data = hex"c9978d2400000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000001f0000000000000000000000000000000000000000000000000000000000000072232800610400000000000000210000000000646ec8170000000000000000000000000000000000000000000000000000e35fa931a0000000000000000000000000000000000000000000000000000000e35fa931a000db0199d8823285940c02787e83948e7ad29abe3a99b29c480f9f009600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060961513acba8e18b55c4b8ba92a9bd6c80e5248f88d5e2e8c8f446fc0dd59c75ccb0b686880fffc65ece58473dbf565b40f71ec31fa2fe50f9d950bf4fd81c7922e354e943c194aefac76e54b8897cbcbb717028ff440735a47d44d81f1cf4156";
        replayTx(relayer, data);
    }

    function test_deleteGroup_handlePackage() public {
        vm.createSelectFork("bsc-test", 30079603);
        address relayer = 0x24aaB6f85470ff73e3048c64083a09e980d4CB7F;
        bytes memory data = hex"c9978d24000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000001f000000000000000000000000000000000000000000000000000000000000003e232800610600000000000000450100000000646e059e0000000000000000000000000000000000000000000000000000e35fa931a000c70385c48081aa8000000000000000000000000000000000000000000000000000000000000000000060b0d9259e0ffbe68d8b77e21bc4c07e0a9e85797694e2d53622e2c8ebbfb5a8525913d269dd037b981d76d4d1a1dd59810bdb2e19600ff2555f543cc55460a2510e1c382646e702f1006987e04eee0fe6dcceccb12802d684c85e7ef5f2f18290";
        replayTx(relayer, data);
    }

    function test_createGroup_handlePackage() public {
        vm.createSelectFork("bsc-test", 30079589);
        address relayer = 0x4998F6Ef8d999A0F36a851BfA29Dbcf0364dd656;
        bytes memory data = hex"c9978d2400000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000001f000000000000000000000000000000000000000000000000000000000000006a232800610600000000000000440100000000646e057b0000000000000000000000000000000000000000000000000000e35fa931a000f304b1f08081aa94d510b9b68afabe68a2038deb9fb50f2e9b9e719e80d59456f51ff23d6863a23798cb77d221b0dd7a0e3749800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000608dffbfddf8d906fe4cf256c40cef76be012c7f5d002b6f6b039bd83f5daa6cb516837fdc5110e2eb39c1eb88fb69ecc8136fc1b43d1729947e1985fda51ae9cee8a70d5f1258b240f245638c5c9db1c004e3e257d1b5dbc6cd3140fda5724384";
        replayTx(relayer, data);
    }

    function test_deleteObject_handlePackage() public {
        vm.createSelectFork("bsc-test", 30079294);
        address relayer = 0x0dfA99423d3084C596C5E3Bd6BCb4F654516517B;
        bytes memory data = hex"c9978d24000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000001f000000000000000000000000000000000000000000000000000000000000003f2328006105000000000000000d0100000000646e02050000000000000000000000000000000000000000000000000000e35fa931a000c80386c58082488f80000000000000000000000000000000000000000000000000000000000000000060803ddaa384d37053a156b297de96265d4154ed68716955a5f8394006176b1677f32421c277db791f26c9b15915d1a03507d5ddf19e09fa237ab8d39c143ddf4fb8763af345c812b62e26ccd382c2c2dfd8a0213562e7ed555004b75a33a0ef26";
        replayTx(relayer, data);
    }

    function test_createGroup2_handlePackage() public {
        vm.createSelectFork("bsc-test", 30073023);
        address relayer = 0x0dfA99423d3084C596C5E3Bd6BCb4F654516517B;
        bytes memory data = hex"c9978d24000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000001f0000000000000000000000000000000000000000000000000000000000000053232800610600000000000000240100000000646db8890000000000000000000000000000000000000000000000000000e35fa931a000dc029ad980819594d510b9b68afabe68a2038deb9fb50f2e9b9e719e80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060893ce3b5ae86f7e466991a922b741c0aa5659ef7b31db098ae0d29047292f90871f4375397bd297844e8f697fd44ceb40d785847ee7eea18331223962143377c719b7d13781531b0e72628c2fb8cf6315cabcf5ebe8076315a4634c1a147a4ab";
        replayTx(relayer, data);
    }

    function test_mirrorGroup_handlePackage() public {
        vm.createSelectFork("bsc-test", 30072719);
        address relayer = 0x4202722Cf6a34D727bE762b46825B0d26b6263A0;
        bytes memory data = hex"c9978d2400000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000001f0000000000000000000000000000000000000000000000000000000000000071232800610600000000000000210000000000646db4fa0000000000000000000000000000000000000000000000000000e35fa931a0000000000000000000000000000000000000000000000000000000e35fa931a000da0198d7819294d510b9b68afabe68a2038deb9fb50f2e9b9e719e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060a5d8ae50eb63bdc8a77816606ea8919a40abc24fc5a8447d41dfa5994a17e20a8bac636734213ba1ded7d1c6596af4030f5e21c75a017f36c242eb133031fdad20b997f20d454a33c61293269f0e83e83203728d48890b493d2511228c4a1606";
        replayTx(relayer, data);
    }

    function test_mirrorObject_handlePackage() public {
        vm.createSelectFork("bsc-test", 30072640);
        address relayer = 0x4202722Cf6a34D727bE762b46825B0d26b6263A0;
        bytes memory data = hex"c9978d2400000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000001f00000000000000000000000000000000000000000000000000000000000000722328006105000000000000000a0000000000646db40c0000000000000000000000000000000000000000000000000000e35fa931a0000000000000000000000000000000000000000000000000000000e35fa931a000db0199d88246a594d510b9b68afabe68a2038deb9fb50f2e9b9e719e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006083d851da25f9c01fb3667137db4645bf780de456d3bfafcd9cce163bd31a95a86ca60ae945fdb4d049fcc290ea3286130fabdcfd982ab9925a48c6b4d7aff5497845b22c24942ced67aa95ad18effa6950eb137bc8de3c7d70adf802e78c3fce";
        replayTx(relayer, data);
    }

    function test_mirrorObject2_handlePackage() public {
        vm.createSelectFork("bsc-test", 30071415);
        address relayer = 0x4998F6Ef8d999A0F36a851BfA29Dbcf0364dd656;
        bytes memory data = hex"c9978d2400000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000001f00000000000000000000000000000000000000000000000000000000000000722328006104000000000000001b0000000000646da5b20000000000000000000000000000000000000000000000000000e35fa931a0000000000000000000000000000000000000000000000000000000e35fa931a000db0199d882314794c3108c8021f85337c71cd267af2349f1a5638d4b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060b08aa1532903500d3d5bb80efbec923b7c4742572df283afa7025dcedbf935f237445d027bd63e12bcbfdbe7b4949320187a19ec3ed45709c000ebff51001cf6fff50ad8f1c9b617f3487cd9a2453ed75199ecc4b0302f9fc719d1bf7188426f";
        replayTx(relayer, data);
    }
}
