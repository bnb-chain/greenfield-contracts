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
    address public constant PROXY_ADMIN = 0xd8058efe0198ae9dD7D563e1b4938Dcbc86A1F81;
    address public constant GOV_HUB = 0x6D544390Eb535d61e196c87d6B9c80dCD8628Acd;
    address public constant CROSS_CHAIN = 0xB1eDe3F5AC8654124Cb5124aDf0Fd3885CbDD1F7;
    address public constant TOKEN_HUB = 0xA6D6d7c556ce6Ada136ba32Dbe530993f128CA44;
    address public constant LIGHT_CLIENT = 0xa8CB3Fa9110c3d9104DAC4B720928352F6a373dC;
    address public constant RELAYER_HUB = 0x2ACDe8bc8567D49CF2Fe54999d4d4A1cd1a9fFEA;


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
