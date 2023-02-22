// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/GnfdLightClient.sol";

contract GnfdLightClientTest is Test {
    address private developer = 0x0000000000000000000000000000000012345678;
    address private user1 = 0x1000000000000000000000000000000012345678;
    address private relayer0 = 0x6e7eAeB9D235D5A0f38D6e3Da558BD500F1dff34;
    address private relayer1 = 0xB5EE9c977f4A1679Af2025FD6a1FaC7240c9D50D;
    address private relayer2 = 0xE732055240643AE92A3668295d398C7ddd2dA810;

    bytes public constant init_cs_bytes =
        hex"677265656e6669656c645f393030302d313231000000000000000000000000000000000000000001a08cee315201a7feb401ba9f312ec3027857b3580f15045f425f44b77bbfc81cb26884f23fb9b226f5f06f8d01018402b3798555359997fcbb9c08b062dcce9800000000000027106e7eaeb9d235d5a0f38d6e3da558bd500f1dff3492789ccca38e43af7040d367f0af050899bbff1114727593759082cc5ff0984089171077f714371877b16d28d56ffe9d42963ecb1e1e4b3e6e2085fcf0d44eedad9c40c5f9b725b115c659cbf0e36d410000000000002710b5ee9c977f4a1679af2025fd6a1fac7240c9d50d8ea2f08235b9cf8b24a030401a1abd3d8df2d53b844acfd0f360de844fce39ccef6899c438f03abf053eca45fde7111b53eadb1084705ef2c90f2a52e46819e8a22937f1cc80f12d7163c8b47c11271f0000000000002710e732055240643ae92a3668295d398c7ddd2da81098a287cb5d67437db9e7559541142e01cc03d5a1866d7d504e522b2fbdcb29d755c1d18c55949b309f2584f0c49c0dcc";
    GnfdLightClient public lightClient;

    function setUp() public {
        vm.createSelectFork("test");
        console.log("block.number", block.number);
        console.log("block.chainid", block.chainid);
    }

    function test_initialize() public {
        init();
    }

    function init() internal {
        lightClient = new GnfdLightClient();
        lightClient.initialize(init_cs_bytes);

        console.log("lightClient.chainID()");
        console.log(string(abi.encode(lightClient.chainID())));

        assertEq(lightClient.gnfdHeight(), uint64(1));
        assertEq(
            lightClient.nextValidatorSetHash(), hex"a08cee315201a7feb401ba9f312ec3027857b3580f15045f425f44b77bbfc81c"
        );

        (bytes32 pubKey, int64 votingPower, address relayerAddress, bytes memory relayerBlsKey) =
            lightClient.validatorSet(0);

        assertEq(pubKey, hex"b26884f23fb9b226f5f06f8d01018402b3798555359997fcbb9c08b062dcce98");
        assertEq(votingPower, int64(10000));
        assertEq(relayerAddress, relayer0);
        assertEq(
            relayerBlsKey,
            hex"92789ccca38e43af7040d367f0af050899bbff1114727593759082cc5ff0984089171077f714371877b16d28d56ffe9d"
        );

        (pubKey, votingPower, relayerAddress, relayerBlsKey) = lightClient.validatorSet(1);
        assertEq(pubKey, hex"42963ecb1e1e4b3e6e2085fcf0d44eedad9c40c5f9b725b115c659cbf0e36d41");
        assertEq(votingPower, int64(10000));
        assertEq(relayerAddress, relayer1);
        assertEq(
            relayerBlsKey,
            hex"8ea2f08235b9cf8b24a030401a1abd3d8df2d53b844acfd0f360de844fce39ccef6899c438f03abf053eca45fde7111b"
        );

        (pubKey, votingPower, relayerAddress, relayerBlsKey) = lightClient.validatorSet(2);
        assertEq(pubKey, hex"53eadb1084705ef2c90f2a52e46819e8a22937f1cc80f12d7163c8b47c11271f");
        assertEq(votingPower, int64(10000));
        assertEq(relayerAddress, relayer2);
        assertEq(
            relayerBlsKey,
            hex"98a287cb5d67437db9e7559541142e01cc03d5a1866d7d504e522b2fbdcb29d755c1d18c55949b309f2584f0c49c0dcc"
        );
    }

    function test_bytes_concat(bytes memory input1, bytes memory input2) public {
        bytes memory output1 = BytesLib.concat(abi.encode(input1), input2);
        bytes memory output2 = abi.encodePacked(abi.encode(input1), input2);
        assertEq(output1, output2);

        output1 = BytesLib.concat(input2, input1);
        output2 = abi.encodePacked(input2, input1);
        assertEq(output1, output2);
    }
}
