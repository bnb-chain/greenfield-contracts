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
    address public constant PROXY_ADMIN = 0xB5d064b44960FdedA1072f983C3E8f1e123cE154;
    address public constant GOV_HUB = 0xA43C8fA0cb6567312091fb14ebf4d0f65De4a6E4;
    address public constant CROSS_CHAIN = 0x39c3A55F68Bf9f2992776991F25Aac6813a4F1d0;
    address public constant TOKEN_HUB = 0x5bFD50cBC7139F731a576a8dd7375c8D0ec48eba;
    address public constant LIGHT_CLIENT = 0x0D077176f54744A78Da0B8CBB58Fdd76552B4ead;
    address public constant RELAYER_HUB = 0x3fe71142DFD985400eedE943A5494c7310B4af18;

    modifier onlyGov() {
        require(msg.sender == GOV_HUB, "only GovHub contract");
        _;
    }

    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
}
