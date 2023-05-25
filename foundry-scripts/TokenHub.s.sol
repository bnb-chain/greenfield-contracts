pragma solidity ^0.8.0;

import "../contracts/Deployer.sol";
import "../contracts/CrossChain.sol";
import "../contracts/middle-layer/TokenHub.sol";
import "./Helper.sol";

contract TokenHubScript is Helper {
    Deployer private deployer;
    TokenHub private tokenHub;
    CrossChain private crossChain;

    function transferOut(address receiver, uint256 amount) public {
        deployer = Deployer(getDeployer());
        crossChain = CrossChain(payable(deployer.proxyCrossChain()));
        tokenHub = TokenHub(payable(deployer.proxyTokenHub()));

        console.log('sender', tx.origin);
        console.log('receiver', receiver);

        uint256 relayFee = crossChain.relayFee();
        uint256 minAckRelayFee = crossChain.minAckRelayFee();
        console.log('total relay fee', relayFee + minAckRelayFee);

        uint256 totalValue = amount + relayFee + minAckRelayFee;
        console.log('total value of tx', totalValue);


        // start broadcast real tx
        vm.startBroadcast();

        tokenHub.transferOut{ value: totalValue }(receiver, amount);

        vm.stopBroadcast();
    }
}
