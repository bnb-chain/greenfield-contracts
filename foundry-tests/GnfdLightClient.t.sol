// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "contracts/GnfdLightClient.sol";

contract GnfdLightClientTest is Test {
    address private developer = 0x0000000000000000000000000000000012345678;
    address private user1 = 0x1000000000000000000000000000000012345678;
    address private relayer0 = 0x414FEBEB91dbb7c174298918326D406A11ffE127;
    address private relayer1 = 0xd3d8b58Fa0fb703bc3872F18CbEfC27260243198;
    address private relayer2 = 0xF99ceEE7c4a1DDeeb07E333262b6Cc12A6770c7d;

    bytes public constant init_cs_bytes =
        hex"677265656e6669656c645f353630302d310000000000000000000000000000000000000000003ee43709ffd55d10f04e736e16cc873da10dcf8f4f895da73f673a691e8252fdd349bf08222b4ab50208479ab201e867be3f1bcfdd98087a18eb07be378dfd6ae92500000000000003e8414febeb91dbb7c174298918326d406a11ffe1279594bdda1c35738297b11940c23b892fbceff5c52314f5d60a95d51232bce0b86ce3279e3ead2dfcd3683de3d349bfa945121b8d28cc9efa806fdf51f716c9c8fcc089db36c032d9c32a66c1f3e2adfb00000000000003e8d3d8b58fa0fb703bc3872f18cbefc2726024319896b702bbea9dcfdbf2e652bd52d8cf7001a061cc9d7721bf0bad6ecbcb1d37dd8aaf335ca2645ad43a8d553fc08e811c0d197814a0e74a7381ce5c49453fd89d39323dcd065ec21883b152146f15c1ed00000000000003e8f99ceee7c4a1ddeeb07e333262b6cc12a6770c7d9129b63adf1dccc26385fe1ec5cd20576e4264d02a0515bb439c03e0ef15de283d9149cb0383d2e47186ae1a3bd0fc593e4299d74ec4ba1a08bcc66e3349b26bc01c4f0cd4899133d2cee3280dc2253b00000000000003e8c9c16bff2a82282818fae17e9722a3ad1e702eb7adfadadb29ee30667d5cc4fbbb1ea0506446876baeb5532f47f021afe9983df9483cbfde032a5e6cd2007662bcc80a8a7e40fe3f3047643350bacb6928222df70daab495d49f7be5aec375af8a8bfa9b00000000000003e8d11a7cd719d7fc1a6cc28a2a6f8471f7f96aceb0979ec397fc7c60329dc94b816d7e55a3818801c0237563c6f7ac9f3a7b1155744168efb09988ef3222c8e0000776ef4a";
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

        assertEq(lightClient.gnfdHeight(), uint64(16100));
        assertEq(
            lightClient.nextValidatorSetHash(),
            hex"3709ffd55d10f04e736e16cc873da10dcf8f4f895da73f673a691e8252fdd349"
        );

        (bytes32 pubKey, int64 votingPower, address relayerAddress, bytes memory relayerBlsKey) = lightClient
            .validatorSet(0);

        assertEq(pubKey, hex"bf08222b4ab50208479ab201e867be3f1bcfdd98087a18eb07be378dfd6ae925");
        assertEq(votingPower, int64(1000));
        assertEq(relayerAddress, relayer0);
        assertEq(
            relayerBlsKey,
            hex"9594bdda1c35738297b11940c23b892fbceff5c52314f5d60a95d51232bce0b86ce3279e3ead2dfcd3683de3d349bfa9"
        );

        (pubKey, votingPower, relayerAddress, relayerBlsKey) = lightClient.validatorSet(1);
        assertEq(pubKey, hex"45121b8d28cc9efa806fdf51f716c9c8fcc089db36c032d9c32a66c1f3e2adfb");
        assertEq(votingPower, int64(1000));
        assertEq(relayerAddress, relayer1);
        assertEq(
            relayerBlsKey,
            hex"96b702bbea9dcfdbf2e652bd52d8cf7001a061cc9d7721bf0bad6ecbcb1d37dd8aaf335ca2645ad43a8d553fc08e811c"
        );

        (pubKey, votingPower, relayerAddress, relayerBlsKey) = lightClient.validatorSet(2);
        assertEq(pubKey, hex"0d197814a0e74a7381ce5c49453fd89d39323dcd065ec21883b152146f15c1ed");
        assertEq(votingPower, int64(1000));
        assertEq(relayerAddress, relayer2);
        assertEq(
            relayerBlsKey,
            hex"9129b63adf1dccc26385fe1ec5cd20576e4264d02a0515bb439c03e0ef15de283d9149cb0383d2e47186ae1a3bd0fc59"
        );
    }
/*
    function test_syncLightBlock() public {
        init();

        bytes memory lightBlockBytes = hex'0aa7090adb030a02080b1211677265656e6669656c645f353630302d3118a0b404220c0881a09ca10610b79aa7c8022a480a209f14f9c4aff46235a1ca3b132e416e7b616fd5fac2903c1ef66c0591fc90abbf1224080112203109b49b42d06970966b77189444d0d3032a0ce66e68171b42956a3b428de54a3220f31a5df9d2c57d1852d2ef857a369596ad7dee9bfb5beb1968cde7b5376ac2ae3a20e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b8554220da613bca8158608f5bb32af1a6561f4142807d4b8c957b5ab173fb49af3cf9524a20da613bca8158608f5bb32af1a6561f4142807d4b8c957b5ab173fb49af3cf9525220048091bc7ddc283f77bfbf91d73c44da58c3df8a9cbc867405d8b7f3daada22f5a202cd633bfe3868cd570c83eb66a246d87c65118d7799bba7804ad52a269d961ee6220e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b8556a20e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b85572149dc29e26798e18b1b1e824c1102d3b349fd689087a40884c1b91539bef1aac726b3123e4a1f1f0401cfd9dcba06370df07d38a8c50bc7f9c9c2824a85d24835bf4657354354b435ef829afa5a5d145e8721a39afd40312c60508a0b4041a480a20a658d6f9a8f05ac1ead962acfc25c21f1fbac491bc703efca05932fe6b67251a12240801122056446e2bb20b11644294d311946c2e71434712d0762e8bf9ccfeaef7c39e12d62267080212141435f19935bac6419e218abdfe820a38fabeea561a0b0884a09ca10610c6e4be7622405d2b2befa143b7b51cec81ddd0fcaa9ac5c6a46db19992a599b18259acef93788d5fb5199288b780be4c725c71581ec8ecc63bf0348eded222ad043bf4ec5d012267080212145e2237e7a837738701d59987734ff21a7005babc1a0b0884a09ca10610fce4ae4822402fd76f857ad3618d713f84bf54ec14bd573a175a67ad8f2a110639bfc634ecf2e91e3f4e157dc49e0023d632e26dd70596e18bbcedf439756c07c3f0bcb04b0c22680802121490c9703686224b5d8010411006181070ebe0a7491a0c0884a09ca10610f6b0fa9901224067412736c6e3d2075b1e1141b5d0404dd483ca6221e47ee2a8d958d85ec011c735a96e1c60996469a701bd38e72108386982f79a0c7a58c991591a4b2972f70a2267080212149dc29e26798e18b1b1e824c1102d3b349fd689081a0b0884a09ca106109ca6b36c22404c6c87ab8bef4dcedcd5eff1aeb160805cf181ffb17a9d9fbb1f8c1d662731bc09ad1e7f1620963b53f171233afba777186d5b34bd37e5b00c7c30d8f4bc320f226708021214bc6453c7c3b104d1acb328f1d438d4fb924f88ba1a0b0884a09ca106109de09b492240ea116f29d7426582a51d8b23237205cd455dfd8cda3de33d17b5e82b9f38a8b23c8df2713b9dc582281f53e2b48125684a3ddcda4f6537f760c1682741c80e07226808021214c8d8fbfefca9fe64880aa876b9d51a943f02fa801a0c0884a09ca10610ece4c199012240a6255d4e6d5f44771725b3e9bb7aa9d000e9584805d24a03a4dd41d6a4221bddd2de1322a124cfda6567e2d29950a90adf9a7553efdcec17beed02cc37f95e0e12f7080aa6010a141435f19935bac6419e218abdfe820a38fabeea5612220a20bf08222b4ab50208479ab201e867be3f1bcfdd98087a18eb07be378dfd6ae92518e80720f8d8ffffffffffffff012a309594bdda1c35738297b11940c23b892fbceff5c52314f5d60a95d51232bce0b86ce3279e3ead2dfcd3683de3d349bfa93214414febeb91dbb7c174298918326d406a11ffe1273a1496e6790caf7beff0d3862c7f665329a0c09544130a9e010a145e2237e7a837738701d59987734ff21a7005babc12220a2045121b8d28cc9efa806fdf51f716c9c8fcc089db36c032d9c32a66c1f3e2adfb18e80720e8072a3096b702bbea9dcfdbf2e652bd52d8cf7001a061cc9d7721bf0bad6ecbcb1d37dd8aaf335ca2645ad43a8d553fc08e811c3214d3d8b58fa0fb703bc3872f18cbefc272602431983a1492f4bbb8d62ff708bdfef71f5f1ebd991d6bdd7e0a9e010a1490c9703686224b5d8010411006181070ebe0a74912220a200d197814a0e74a7381ce5c49453fd89d39323dcd065ec21883b152146f15c1ed18e80720e8072a309129b63adf1dccc26385fe1ec5cd20576e4264d02a0515bb439c03e0ef15de283d9149cb0383d2e47186ae1a3bd0fc593214f99ceee7c4a1ddeeb07e333262b6cc12a6770c7d3a1458d8bcf9e2e76886a1c5031966c26ee4f4f5b7fc0a9e010a149dc29e26798e18b1b1e824c1102d3b349fd6890812220a203e4299d74ec4ba1a08bcc66e3349b26bc01c4f0cd4899133d2cee3280dc2253b18e80720e8072a30adfadadb29ee30667d5cc4fbbb1ea0506446876baeb5532f47f021afe9983df9483cbfde032a5e6cd2007662bcc80a8a3214c9c16bff2a82282818fae17e9722a3ad1e702eb73a14b3b18a3ea7d75fa7f6f4796bc55b2b905c494db30a9e010a14bc6453c7c3b104d1acb328f1d438d4fb924f88ba12220a207e40fe3f3047643350bacb6928222df70daab495d49f7be5aec375af8a8bfa9b18e80720e8072a30979ec397fc7c60329dc94b816d7e55a3818801c0237563c6f7ac9f3a7b1155744168efb09988ef3222c8e0000776ef4a3214d11a7cd719d7fc1a6cc28a2a6f8471f7f96aceb03a14926b82cc069b6388852dcb24db94e7d81f9b05860a9e010a14c8d8fbfefca9fe64880aa876b9d51a943f02fa8012220a207342c9e852d6c1bc904381a19adf1f092247784a5cd6c442955ff8e9f5e157fe18e80720e8072a30b2905d36cfb73989b8168f1938c15e57b04d0794e436a473617955c910e0c0f341625b576192444e96060f3d6311a5eb321462b7e98038db4843d0c28a99f8bc263b535593443a148ef06c2f22fcd3e8e9b7139958bc0280ea2700f212a6010a141435f19935bac6419e218abdfe820a38fabeea5612220a20bf08222b4ab50208479ab201e867be3f1bcfdd98087a18eb07be378dfd6ae92518e80720f8d8ffffffffffffff012a309594bdda1c35738297b11940c23b892fbceff5c52314f5d60a95d51232bce0b86ce3279e3ead2dfcd3683de3d349bfa93214414febeb91dbb7c174298918326d406a11ffe1273a1496e6790caf7beff0d3862c7f665329a0c0954413';
        vm.prank(relayer0);
        lightClient.syncLightBlock(lightBlockBytes, uint64(72224));
    }
    */

    function test_bytes_concat(bytes memory input1, bytes memory input2) public {
        bytes memory output1 = BytesLib.concat(abi.encode(input1), input2);
        bytes memory output2 = abi.encodePacked(abi.encode(input1), input2);
        assertEq(output1, output2);

        output1 = BytesLib.concat(input2, input1);
        output2 = abi.encodePacked(input2, input1);
        assertEq(output1, output2);
    }
}
