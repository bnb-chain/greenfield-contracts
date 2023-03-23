// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

interface IRelayerHub {
    function addReward(address _relayer, uint256 _reward) external;
}
