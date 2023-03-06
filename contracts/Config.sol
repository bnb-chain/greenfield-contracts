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
    address public constant PROXY_ADMIN = 0x3B02fF1e626Ed7a8fd6eC5299e2C54e1421B626B;
    address public constant GOV_HUB = 0xBA12646CC07ADBe43F8bD25D83FB628D29C8A762;
    address public constant CROSS_CHAIN = 0x7ab4C4804197531f7ed6A6bc0f0781f706ff7953;
    address public constant TOKEN_HUB = 0xc8CB5439c767A63aca1c01862252B2F3495fDcFE;
    address public constant LIGHT_CLIENT = 0xD79aE87F2c003Ec925fB7e9C11585709bfe41473;
    address public constant RELAYER_HUB = 0xB7aa4c318000BB9bD16108F81C40D02E48af1C42;

    modifier onlyGov() {
        require(msg.sender == GOV_HUB, "only GovHub contract");
        _;
    }
}
