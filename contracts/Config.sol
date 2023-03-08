// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "./interface/ILightClient.sol";

abstract contract Config {
    uint8 public constant TRANSFER_IN_CHANNEL_ID = 0x01;
    uint8 public constant TRANSFER_OUT_CHANNEL_ID = 0x02;
    uint8 public constant GOV_CHANNEL_ID = 0x03;
    uint8 public constant APP_CHANNEL_ID = 0x04;

    // TODO channel ID
    uint8 public constant BUCKET_CHANNEL_ID = 0x06;
    uint8 public constant OBJECT_CHANNEL_ID = 0x07;
    uint8 public constant GROUP_CHANNEL_ID = 0x08;

    // contract address
    // will calculate their deployed addresses from deploy script
    address public constant PROXY_ADMIN = address(0);
    address public constant GOV_HUB = address(0);
    address public constant CROSS_CHAIN = address(0);
    address public constant TOKEN_HUB = address(0);
    address public constant LIGHT_CLIENT = address(0);
    address public constant RELAYER_HUB = address(0);
    address public constant BUCKET_HUB = address(0);
    address public constant OBJECT_HUB = address(0);
    address public constant GROUP_HUB = address(0);

    // relayer
    uint256 public relayFee;
    uint256 public ackRelayFee;

    modifier onlyGov() {
        require(msg.sender == GOV_HUB, "only GovHub contract");
        _;
    }

    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
}
