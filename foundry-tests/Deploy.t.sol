pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../contracts/Deployer.sol";
import "../contracts/CrossChain.sol";
import "../contracts/GnfdProxy.sol";
import "../contracts/GnfdProxyAdmin.sol";
import "../contracts/GnfdLightClient.sol";
import "../contracts/middle-layer/GovHub.sol";
import "../contracts/middle-layer/TokenHub.sol";

contract DeployTest is Test {
    function setUp() public {}

    function test_generate_address() public {
        console.log("this", address(this));
        MyDeployer deployer = new MyDeployer();

        address nonce1 =
            address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), address(deployer), uint8(1))))));
        address nonce2 =
            address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), address(deployer), uint8(2))))));
        address nonce3 =
            address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), address(deployer), uint8(3))))));
        address nonce4 =
            address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), address(deployer), uint8(4))))));
        //        address nonce5 = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), address(deployer), uint8(5))))));

        console.log(nonce1, nonce2, nonce3, nonce4);

        deployer.deploy();
        console.log(deployer.x1(), deployer.x2(), deployer.x3(), deployer.x4());
    }

    function test_deploy() public {
        Deployer deployer = new Deployer(uint16(1));
        deployer.deploy(
            "", address(deployer), address(deployer), address(deployer), address(deployer), address(deployer)
        );
    }
}

contract MyDeployer {
    address public x1;
    address public x2;
    address public x3;
    address public x4;
    address public x5;

    constructor() {
        x1 = address(new CrossChain());
        x2 = address(new GnfdLightClient());
        x3 = address(new GnfdProxy(x1, x1, ""));
    }

    function deploy() public {
        x4 = address(new GnfdLightClient());
        x5 = address(new GnfdLightClient());
    }
}
