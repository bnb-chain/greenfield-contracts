pragma solidity ^0.8.0;

import "../contracts/Deployer.sol";
import "../contracts/CrossChain.sol";
import "../contracts/middle-layer/TokenHub.sol";
import "./Helper.sol";

contract TokenHubScript is Helper {

    function transferOut(address receiver, uint256 amount) public {
        console.log('sender', tx.origin);
        console.log('receiver', receiver);

        uint256 totalValue = amount + totalRelayFee;
        console.log('total value of tx', totalValue);

        // start broadcast real tx
        vm.startBroadcast();

        tokenHub.transferOut{ value: totalValue }(receiver, amount);

        vm.stopBroadcast();
    }
}
