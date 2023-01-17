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

    Deployer public deployer;
    GovHub public govHub;
    CrossChain public crossChain;
    TokenHub public tokenHub;
    InscriptionLightClient public lightClient;

    address private developer = 0x0000000000000000000000000000000012345678;
    address private user1 = 0x1000000000000000000000000000000012345678;

    function setUp() public {
        deployer = new Deployer(insChainId);
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

