pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../contracts/Deployer.sol";
import "../contracts/CrossChain.sol";
import "../contracts/GnfdProxy.sol";
import "../contracts/GnfdProxyAdmin.sol";
import "../contracts/GnfdLightClient.sol";
import "../contracts/middle-layer/GovHub.sol";
import "../contracts/middle-layer/TokenHub.sol";

import "../contracts/lib/RLPEncode.sol";
import "../contracts/lib/RLPDecode.sol";
import "../contracts/middle-layer/TokenHub.sol";

contract GnfdLightClientTest is Test {
    using RLPEncode for *;
    using RLPDecode for *;

    using RLPDecode for RLPDecode.RLPItem;
    using RLPDecode for RLPDecode.Iterator;

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

    bytes public constant init_cs_bytes =
        hex"677265656e6669656c645f393030302d31323100000000000000000000000000000000000000000102462f6e91df5365091f3c59d088c5b759f07ac5dbc0b9b6e320cb9fceae64ce28ea6c6020c829158f042cda713f5095502633ef83730c7174e5463c439476400000000000002710e739795f096affdccbbe7deb706d9bd0f49c499180d2099554bf089a195f03675d3cdb418a97ad9eda4ece38205acdc486e4f3b667b121bb0be2a8bb43b5fe137a702a459f7722bf35eb0de44df3a7fc393c68804446fd9ba45ab29885db037e630f53c40000000000002710ac225b79eccfe6fe2b13e048f3cb232dd4491b528917a8c44f9cc42374d6f485dd492ec2188dd9a9a8a3b7d1226e734aa8f76a7f68c347ac30feedbb2d4db2b2132e758366b2f09a5327fce99ec3aee86c0f78d1de8e04f13b40b72b0659afaf3b519a8e0000000000002710ec5ad68ee64d0c2ecf86e1983f384e7b4b35fb2a96f23fdf8e1b607ce6cbc1d7e8fc6862b825ccee238c4482f503425891efd4bbae807fc0b9895beac181415a8cf5753c";
    function setUp() public {
        vm.createSelectFork("local");
        console.log("block.number", block.number);
        console.log("block.chainid", block.chainid);
    }

    function test_init() public {
        GnfdLightClient lightClient = new GnfdLightClient();
        lightClient.initialize(init_cs_bytes);

        console.log("lightClient.chainID()");
        console.log(string(abi.encode(lightClient.chainID())));

        console.log("lightClient.height()", lightClient.height());
        console.log("lightClient.initialHeight()", lightClient.initialHeight());

        console.log("lightClient.nextValidatorSetHash()");
        console.logBytes32(lightClient.nextValidatorSetHash());

        (bytes32 pubKey, int64 votingPower, address relayerAddress, bytes memory relayerBlsKey) =
            lightClient.validatorSet(0);

        console.log("pubKey");
        console.logBytes32(pubKey);

        console.log("votingPower", uint64(votingPower));
        console.log("relayerAddress", relayerAddress);

        console.log("relayerBlsKey");
        console.logBytes(relayerBlsKey);

        console.log("-------------------------------------------------start verify pkg");
//        bytes memory payload =
//            hex"10010002010000000000000003000000000063ddf59300000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000eb7b9476d244ce05c3de4bbc6fdd7f56379b145709ade9941ac642f1329404e04850e1dee5e0abe903e62211";

        bytes memory payload =
            hex'00010002010000000000000003000000000063ddf59300000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000eb7b9476d244ce05c3de4bbc6fdd7f56379b145709ade9941ac642f1329404e04850e1dee5e0abe903e62211';
        bytes memory sig =
            hex"b352e9b52ae49bc6ffaf7e975dd7d924ece56b709c88869e22bc832852bf7e033a420f6ca73b74403c46df9f601e323b194602e2ac1fa293f3badf3a306451afa4d071314b73428e99a4da5e444147fe001cb7c7b3d3603a521cbf340e6b1128";
        uint256 bitMap = 7;
        lightClient.verifyPackage(payload, sig, bitMap);
    }


    function test_callView() external view {
        address PACKAGE_VERIFY_CONTRACT = address(0x66);
        (bool success, bytes memory data) = PACKAGE_VERIFY_CONTRACT.staticcall("");
    }

}
