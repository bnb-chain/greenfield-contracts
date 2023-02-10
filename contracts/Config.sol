// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "./interface/ILightClient.sol";

abstract contract Config {
    uint8 public constant TRANSFER_IN_CHANNELID = 0x01;
    uint8 public constant TRANSFER_OUT_CHANNELID = 0x02;
    uint8 public constant APP_CHANNELID = 0x03;
    uint8 public constant GOV_CHANNELID = 0x05;

    uint32 public constant CODE_OK = 0;
    uint32 public constant ERROR_FAIL_DECODE = 100;

    // contract address
    // will calculate their deployed addresses from deploy script
    address public constant PROXY_ADMIN = 0xE2879e482F608a0442D8875cC512Aa74137C7321;
    address public constant GOV_HUB = 0xCcaf9014B607dA3800E82FcD2bc26698dd9936Ba;
    address public constant CROSS_CHAIN = 0x4e3f5142D26b530d86d2Ed47dD4F4F9bCA3A80AE;
    address public constant TOKEN_HUB = 0x455A048290bDCFf3EE88E8E2A0923b5F49b711b2;
    address public constant LIGHT_CLIENT = 0xCf5189a6F94349b76734323a2728ec1DEe1D301b;
    address public constant RELAYER_HUB = 0xcc2B9Def872E748E6b397c2A0d38c67D1b7cCA9e;
}
