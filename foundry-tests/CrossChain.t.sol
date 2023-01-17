pragma solidity ^0.8.0;
import "forge-std/Test.sol";

import "../contracts/Deployer.sol";
import "../contracts/CrossChain.sol";
import "../contracts/InscriptionProxy.sol";
import "../contracts/InscriptionProxyAdmin.sol";
import "../contracts/InscriptionLightClient.sol";
import "../contracts/middle-layer/GovHub.sol";
import "../contracts/middle-layer/TokenHub.sol";

contract CrossChainTest is Test {
    uint16 constant public insChainId = 1;
    bytes constant public blsPubKeys = hex'8ec21505e290d7c15f789c7b4c522179bb7d70171319bfe2d6b2aae2461a1279566782907593cc526a5f2611c0721d60b4a78719a34817cc1d085b6eed110ed1d1ca59a35c9cf4d094e4e71b0b8b76ac2d30ba0762ec9acfaca8b8b369d914e980e970c25a8580cb0d840dce6fff3adc830e16ec8660fb91c8811a28d8ada91d539f82d2730496549e7783a34167498c';
    address[] public relayers = [0x1115E495c48bEb783ee04Ca99b7c2F87Faf6F8eb, 0x56B2404e087F55D6E16bEED3aDee8F51414A301b, 0xE7B8E0894FF97dd5c846c8A031becDb06E2390ea];


    Deployer public deployer;
    GovHub public govHub;
    CrossChain public crossChain;
    TokenHub public tokenHub;
    InscriptionLightClient public lightClient;

    address private developer = 0x0000000000000000000000000000000012345678;
    address private user1 = 0x1000000000000000000000000000000012345678;

    function setUp() public {
        deployer = new Deployer(insChainId, blsPubKeys, relayers);
        deployer.deploy();
        govHub =  GovHub(payable(deployer.proxyGovHub()));
        crossChain =  CrossChain(payable(deployer.proxyCrossChain()));
        tokenHub =  TokenHub(payable(deployer.proxyTokenHub()));
        lightClient =  InscriptionLightClient(payable(deployer.proxyLightClient()));

        vm.deal(developer, 10000 ether);
    }

    function test_correct_case1() public {
        address receipt = user1;
        uint256 amount = 1 ether;
        tokenHub.transferOut{ value: amount + 1 ether }(receipt, amount);
    }

    function iToHex(bytes memory buffer) public pure returns (string memory) {
        // Fixed buffer size for hexadecimal convertion
        bytes memory converted = new bytes(buffer.length * 2);
        bytes memory _base = "0123456789abcdef";
        for (uint256 i = 0; i < buffer.length; i++) {
            converted[i * 2] = _base[uint8(buffer[i]) / _base.length];
            converted[i * 2 + 1] = _base[uint8(buffer[i]) % _base.length];
        }
        return string(abi.encodePacked("0x", converted));
    }
}

