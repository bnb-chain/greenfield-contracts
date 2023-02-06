pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./Config.sol";
import "./interface/IGovHub.sol";
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
    function initialize() public initializer {
        fixedRelayerRewardRatio = 70;
    }

    function addReward(address _relayer, uint256 _reward) external onlyCrossChain {
        uint256 actualAmount = ITokenHub(TOKEN_HUB).claimRelayFee(payable(address(this)), _reward);

        uint256 _fixedReward = _reward * fixedRelayerRewardRatio / REWARD_RATIO_SCALE;
        rewardMap[_relayer] += _fixedReward;

        if (_reward > _fixedReward) {
            _distributeRewards(_reward - _fixedReward);
        }
    }

    function claimReward(address payable _relayer) external {
        uint256 _reward = rewardMap[_relayer];
        require(_reward > 0, "no relayer reward");
        rewardMap[_relayer] = 0;

        require(address(this).balance >= _reward, "relayer reward not enough");
        _relayer.transfer(_reward);

        emit RewardToRelayer(_relayer, _reward);
    }

    /*----------------- internal function -----------------*/
    function _distributeRewards(uint256 _reward) internal {
        address[] memory relayers = ILightClient(LIGHT_CLIENT).getRelayers();

        uint256 _rewardEach = _reward / relayers.length;
        uint256 _remaining = _reward;
        for (uint256 i = 0; i < relayers.length - 1; i++) {
            rewardMap[relayers[i]] += _rewardEach;
            _remaining -= _rewardEach;
        }

        rewardMap[relayers[relayers.length - 1]] += _remaining;
    }
}
