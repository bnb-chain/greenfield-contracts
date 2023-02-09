pragma solidity ^0.8.0;

import "./TestDeployer.sol";
import "../contracts/Deployer.sol";
import "../contracts/CrossChain.sol";
import "../contracts/middle-layer/GovHub.sol";

contract UpgradeTest is TestDeployer {

    function setUp() public {}

    function test_upgrade() public {
        address _deployer = _deployOnTestChain();
        Deployer deployer = Deployer(_deployer);
    }
}
