// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "./interface/ILightClient.sol";

abstract contract Config {
    uint8 public constant TRANSFER_IN_CHANNEL_ID = 0x01;
    uint8 public constant TRANSFER_OUT_CHANNEL_ID = 0x02;
    uint8 public constant GOV_CHANNELID = 0x03;

    uint32 public constant CODE_OK = 0;
    uint32 public constant ERROR_FAIL_DECODE = 100;

    // contract address
    // will calculate their deployed addresses from deploy script
    address public constant PROXY_ADMIN = 0x8e95fFcCC4d38C8c85C27C1c830F926beeC8e7af;
    address public constant GOV_HUB = 0xe2f6fc717bf51b2520fFf75DF9d9eb66a8c12259;
    address public constant CROSS_CHAIN = 0xd2253A26e6d5b729dDBf4bCce5A78F93C725b455;
    address public constant TOKEN_HUB = 0x205C28DE83D33ED7CA634A449b6eFfB6B84F88fA;
    address public constant LIGHT_CLIENT = 0x349a42f907c7562B3aaD4431780E4596bC2a053f;
    address public constant RELAYER_HUB = 0x5fa079400E0A2e264E5d072594F7f8E117223101;


    modifier onlyCrossChain() {
        require(msg.sender == CROSS_CHAIN, "only CrossChain contract");
        _;
    }

    modifier onlyGov() {
        require(msg.sender == GOV_HUB, "only GovHub contract");
        _;
    }

    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function upgradeInfo() external pure virtual returns (uint256 version, string memory name, string memory description) {
        return (0, "Config", "");
    }
}
