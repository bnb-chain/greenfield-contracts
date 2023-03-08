// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "./interface/ILightClient.sol";

abstract contract Config {
    uint8 public constant TRANSFER_IN_CHANNELID = 0x01;
    uint8 public constant TRANSFER_OUT_CHANNELID = 0x02;
    uint8 public constant GOV_CHANNELID = 0x03;
    uint8 public constant APP_CHANNELID = 0x04;

    uint32 public constant CODE_OK = 0;
    uint32 public constant ERROR_FAIL_DECODE = 100;

    // contract address
    // will calculate their deployed addresses from deploy script
    address public constant PROXY_ADMIN = address(0);
    address public constant GOV_HUB = address(0);
    address public constant CROSS_CHAIN = address(0);
    address public constant TOKEN_HUB = address(0);
    address public constant LIGHT_CLIENT = address(0);
    address public constant RELAYER_HUB = address(0);

    modifier onlyGov() {
        require(msg.sender == GOV_HUB, "only GovHub contract");
        _;
    }

    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
}
