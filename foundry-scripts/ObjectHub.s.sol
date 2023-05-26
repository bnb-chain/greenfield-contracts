pragma solidity ^0.8.0;

import "./Helper.sol";

contract ObjectHubScript is Helper {

    function deleteObject(uint256 id) external {
        console.log("the object id to delete", id);

        // start broadcast real tx
        vm.startBroadcast();

        objectHub.deleteObject{ value: totalRelayFee }(id);

        vm.stopBroadcast();
    }

}
