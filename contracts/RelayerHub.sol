// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./Config.sol";
import "./interface/ITokenHub.sol";
import "./interface/ILightClient.sol";

contract RelayerHub is Initializable, Config {
    uint256 public constant REWARD_RATIO_SCALE = 100;

    /*----------------- storage layer -----------------*/
    uint256 public fixedRelayerRewardRatio;
    mapping(address => uint256) public rewardMap;

    /*----------------- event / modifier -----------------*/
    event RewardToRelayer(address relayer, uint256 amount);

    modifier onlyCrossChain() {
        require(msg.sender == CROSS_CHAIN, "only cross chain contract");
        _;
    }

    /*----------------- external function -----------------*/
    receive() external payable {}

    function initialize() public initializer {
        fixedRelayerRewardRatio = 70;
    }

    function addReward(address _relayer, uint256 _reward) external onlyCrossChain {
        ITokenHub(TOKEN_HUB).claimRelayFee(_reward);

        uint256 _fixedReward = _reward * fixedRelayerRewardRatio / REWARD_RATIO_SCALE;
        rewardMap[_relayer] += _fixedReward;
    }

    function claimReward(address payable _relayer) external {
        uint256 _reward = rewardMap[_relayer];
        require(_reward > 0, "no relayer reward");
        rewardMap[_relayer] = 0;

        require(address(this).balance >= _reward, "relayer reward not enough");
        _relayer.transfer(_reward);

        emit RewardToRelayer(_relayer, _reward);
    }
}
