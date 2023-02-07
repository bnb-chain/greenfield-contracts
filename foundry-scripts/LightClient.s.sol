pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../contracts/GnfdProxy.sol";
import "../contracts/GnfdProxyAdmin.sol";
import "../contracts/GnfdLightClient.sol";
import "../contracts/CrossChain.sol";
import "../contracts/middle-layer/GovHub.sol";
import "../contracts/middle-layer/TokenHub.sol";

contract LightClientScript is Script {
    GnfdLightClient public lightClient;
    bytes public constant init_cs_bytes =
        hex"677265656e6669656c645f393030302d313231000000000000000000000000000000000000000001a5f1af4874227f1cdbe5240259a365ad86484a4255bfd65e2a0222d733fcdbc320cc466ee9412ddd49e0fff04cdb41bade2b7622f08b6bdacac94d4de03bdb970000000000002710d5e63aeee6e6fa122a6a23a6e0fca87701ba1541aa2d28cbcd1ea3a63479f6fb260a3d755853e6a78cfa6252584fee97b2ec84a9d572ee4a5d3bc1558bb98a4b370fb8616b0b523ee91ad18a63d63f21e0c40a83ef15963f4260574ca5159fd90a1c527000000000000027106fd1ceb5a48579f322605220d4325bd9ff90d5fab31e74a881fc78681e3dfa440978d2b8be0708a1cbbca2c660866216975fdaf0e9038d9b7ccbf9731f43956dba7f2451919606ae20bf5d248ee353821754bcdb456fd3950618fda3e32d3d0fb990eeda000000000000271097376a436bbf54e0f6949b57aa821a90a749920ab32979580ea04984a2be033599c20c7a0c9a8d121b57f94ee05f5eda5b36c38f6e354c89328b92cdd1de33b64d3a0867";
    address relayer0 = 0xd5E63aeee6e6FA122a6a23A6e0fCA87701ba1541;

    function deployAndInit() public {
        uint256 privateKey = uint256(vm.envBytes32("PK1"));
        address developer = vm.addr(privateKey);
        console.log("developer", developer, developer.balance);
        console.log("relayer0", relayer0, relayer0.balance);
        console.log("block info", block.chainid, block.number);

        vm.startBroadcast();
        lightClient = new GnfdLightClient();
        lightClient.initialize(init_cs_bytes);
        vm.stopBroadcast();

        console.log("--------------------------------------------");
        console.log("lightClient", address(lightClient));
        console.log("--------------------------------------------");
    }

    function verifyPkg() public {
        uint256 privateKey = uint256(vm.envBytes32("PK1"));
        address developer = vm.addr(privateKey);
        console.log("developer", developer, developer.balance);
        console.log("-------------------------------------------------start verify pkg");

        bytes memory payload =
            hex"10010002010000000000000003000000000063ddf59300000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000eb7b9476d244ce05c3de4bbc6fdd7f56379b145709ade9941ac642f1329404e04850e1dee5e0abe903e62211";
        bytes memory sig =
            hex"b352e9b52ae49bc6ffaf7e975dd7d924ece56b709c88869e22bc832852bf7e033a420f6ca73b74403c46df9f601e323b194602e2ac1fa293f3badf3a306451afa4d071314b73428e99a4da5e444147fe001cb7c7b3d3603a521cbf340e6b1128";
        uint256 bitMap = 7;

        address _lightClient = 0x610178dA211FEF7D417bC0e6FeD39F05609AD788;
        vm.startBroadcast();
        GnfdLightClient(_lightClient).verifyPackage(payload, sig, bitMap);
        vm.stopBroadcast();
    }

    function transferToRelayer() public {
        uint256 privateKey = uint256(vm.envBytes32("PK1"));
        address developer = vm.addr(privateKey);
        console.log("developer", developer, developer.balance);

        vm.startBroadcast();
        payable(relayer0).transfer(789 * 1e18);
        vm.stopBroadcast();
    }

    function syncLightBlock() public {
        console.log("relayer0", relayer0, relayer0.balance);

        address _lightClient = 0x959922bE3CAee4b8Cd9a407cc3ac1C251C2007B1;
        bytes memory _header =
            hex"0aa6060a99030a02080b1213677265656e6669656c645f393030302d3132311802220c08d2aafd9e0610d8f9e1eb022a480a204015d7d8169ab6769dbf1f45ee16a190ed46bc00bd0660a5fd820677cad4bde71224080112202457fe25a28709a079ad8c108535331db3f64a8bde4fa9f4d17325af196c68db322026205de8b72d0aec55faca9b7ee9f12a70b0aa790223807ce242f483c862cb853a20e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b8554220a5f1af4874227f1cdbe5240259a365ad86484a4255bfd65e2a0222d733fcdbc34a20a5f1af4874227f1cdbe5240259a365ad86484a4255bfd65e2a0222d733fcdbc35220048091bc7ddc283f77bfbf91d73c44da58c3df8a9cbc867405d8b7f3daada22f5a2019f1bd914ccd73076d7f267288077557d0073d0332cc8a6dd90c64fb61a0cacb6220e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b8556a20e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b8557214181b1681f0a2062e0af512b8052e62cd17824e2e12870308021a480a204c7d6aef71e381a55d2b184f250c0b194f21b4be987bac24e3a8efca0adc92041224080112204d8f2e9efbf01e6db4529a0bd095ba8b3c4c11337a53352abd944f0a900ef15122670802121409207f5faa1bd0a74a13f733724267e65b37b69e1a0b08d8aafd9e0610d8fcb52c22407bb3e5146a9cda4f3712945accfbb67a27f04034c145c6e9ead73266187696447bfa0fca8b9167d2ae0ca4c36751319d12093580c2936c1da0e7d34338205e06226708021214181b1681f0a2062e0af512b8052e62cd17824e2e1a0b08d8aafd9e0610c886e62e224073d8c8d728bbfdf609a8153b1cda13c3659df28fb658eb4d8efb66fcdd0b4ea645f19a8360830d3ab7823dffe54887507a1dc8269a851d4572df264bd943aa06226708021214c057394359aa7259e175ac54d10363e70cae78ea1a0b08d8aafd9e0610f086a131224054f9a07868326636a9a38fac00dae514c45c706858978524a374ff6afc7baff597ae26b0503749789b6ab8f14bd2c469ceb5e1ba4b82c0cf908c8e664597d20012bc040a90010a1409207f5faa1bd0a74a13f733724267e65b37b69e12220a2020cc466ee9412ddd49e0fff04cdb41bade2b7622f08b6bdacac94d4de03bdb9718904e20e0e3feffffffffffff012a30aa2d28cbcd1ea3a63479f6fb260a3d755853e6a78cfa6252584fee97b2ec84a9d572ee4a5d3bc1558bb98a4b370fb8613214d5e63aeee6e6fa122a6a23a6e0fca87701ba15410a88010a14181b1681f0a2062e0af512b8052e62cd17824e2e12220a206b0b523ee91ad18a63d63f21e0c40a83ef15963f4260574ca5159fd90a1c527018904e20904e2a30b31e74a881fc78681e3dfa440978d2b8be0708a1cbbca2c660866216975fdaf0e9038d9b7ccbf9731f43956dba7f245132146fd1ceb5a48579f322605220d4325bd9ff90d5fa0a88010a14c057394359aa7259e175ac54d10363e70cae78ea12220a20919606ae20bf5d248ee353821754bcdb456fd3950618fda3e32d3d0fb990eeda18904e20904e2a30b32979580ea04984a2be033599c20c7a0c9a8d121b57f94ee05f5eda5b36c38f6e354c89328b92cdd1de33b64d3a0867321497376a436bbf54e0f6949b57aa821a90a749920a1290010a1409207f5faa1bd0a74a13f733724267e65b37b69e12220a2020cc466ee9412ddd49e0fff04cdb41bade2b7622f08b6bdacac94d4de03bdb9718904e20e0e3feffffffffffff012a30aa2d28cbcd1ea3a63479f6fb260a3d755853e6a78cfa6252584fee97b2ec84a9d572ee4a5d3bc1558bb98a4b370fb8613214d5e63aeee6e6fa122a6a23a6e0fca87701ba1541";
        uint64 _height = 2;

        vm.startBroadcast();
        GnfdLightClient(_lightClient).syncLightBlock(_header, _height);
        vm.stopBroadcast();
    }
}
