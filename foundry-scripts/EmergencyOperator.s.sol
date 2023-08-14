pragma solidity ^0.8.0;

import "./Helper.sol";
contract EmergencyOperatorScript is Helper {

    struct ParamChangePackage {
        string key;
        bytes values;
        bytes targets;
    }

    function generateEmergencyUpgrade(address target, address newImpl) external view {
        string memory key = "upgrade";
        bytes memory values = abi.encodePacked(newImpl);
        bytes memory targets = abi.encodePacked(target);

        console.log("key", key);

        console.log("values: ");
        console.logBytes(values);

        console.log("targets: ");
        console.logBytes(targets);
    }

    function generateEmergencyUpgrades(address[] memory _targets, address[] memory _newImpls) external view {
        string memory key = "upgrade";
        bytes memory values = abi.encodePacked(_newImpls);
        bytes memory targets = abi.encodePacked(_targets);

        console.log("key", key);

        console.log("values: ");
        console.logBytes(values);

        console.log("targets: ");
        console.logBytes(targets);
    }

    function generateEmergencyUpdateParam(string memory key, address target, uint256 newValue) external view {
        bytes memory values = abi.encodePacked(newValue);
        bytes memory targets = abi.encodePacked(target);

        console.log("key", key);

        console.log("values: ");
        console.logBytes(values);

        console.log("targets: ");
        console.logBytes(targets);
    }

}
