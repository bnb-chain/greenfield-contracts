pragma solidity ^0.8.0;

import "./Helper.sol";
contract EmergencyOperatorScript is Helper {

    struct ParamChangePackage {
        string key;
        bytes values;
        bytes targets;
    }

    function generateEmergencyUpgrade(address target, address newImpl) external {
        string memory key = "upgrade";
        bytes memory values = abi.encodePacked(newImpl);
        bytes memory targets = abi.encodePacked(target);

        console.log("key", key);

        console.log("values: ");
        console.logBytes(values);

        console.log("targets: ");
        console.logBytes(targets);

        // start broadcast real tx
        vm.startBroadcast();
        govHub.emergencyUpdate(key, values, targets);
        vm.stopBroadcast();
    }

    function generateEmergencyUpgrades(address[] memory _targets, address[] memory _newImpls) external {
        string memory key = "upgrade";
        require(_targets.length == _newImpls.length, "length not match");

        bytes memory values = _addressListToBytes(_newImpls);
        bytes memory targets = _addressListToBytes(_targets);

        console.log("key", key);

        console.log("values: ");
        console.logBytes(values);

        console.log("targets: ");
        console.logBytes(targets);

        // start broadcast real tx
        vm.startBroadcast();
        govHub.emergencyUpdate(key, values, targets);
        vm.stopBroadcast();
    }

    function generateEmergencyUpdateParam(string memory key, address target, uint256 newValue) external {
        bytes memory values = abi.encodePacked(newValue);
        bytes memory targets = abi.encodePacked(target);

        console.log("key", key);

        console.log("values: ");
        console.logBytes(values);

        console.log("targets: ");
        console.logBytes(targets);

        // start broadcast real tx
        vm.startBroadcast();
        govHub.emergencyUpdate(key, values, targets);
        vm.stopBroadcast();
    }

    function emergencySuspend() external {
        // start broadcast real tx
        vm.startBroadcast();
        crossChain.emergencySuspend();
        vm.stopBroadcast();
    }

    function emergencyReopen() external {
        // start broadcast real tx
        vm.startBroadcast();
        crossChain.emergencyReopen();
        vm.stopBroadcast();
    }

    function emergencyCancelTransfer(address attacker) external {
        // start broadcast real tx
        vm.startBroadcast();
        crossChain.emergencyCancelTransfer(attacker);
        vm.stopBroadcast();
    }

    function _addressListToBytes(address[] memory _addresses) internal pure returns (bytes memory) {
        bytes memory result = new bytes(_addresses.length * 20);
        for (uint256 i = 0; i < _addresses.length; i++) {
            for (uint256 j = 0; j < 20; j++) {
                result[i * 20 + j] = bytes20(_addresses[i])[j];
            }
        }
        return result;
    }
}
