// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "./interface/ILightClient.sol";

abstract contract Config {
    uint8 public constant TRANSFER_IN_CHANNELID = 0x01;
    uint8 public constant TRANSFER_OUT_CHANNELID = 0x02;
    uint8 public constant APP_CHANNELID = 0x03;
    uint8 public constant GOV_CHANNELID = 0x05;

    // TODO channel ID
    uint8 public constant MIRROR_BUCKET_CHANNELID = 0x06;
    uint8 public constant MIRROR_OBJECT_CHANNELID = 0x07;
    uint8 public constant MIRROR_GROUP_CHANNELID = 0x08;

    uint8 public constant CREATE_BUCKET_CHANNELID = 0x09;
    uint8 public constant DELETE_BUCKET_CHANNELID = 0x10;
    uint8 public constant CREATE_GROUP_CHANNELID = 0x11;
    uint8 public constant DELETE_GROUP_CHANNELID = 0x12;

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
    address public constant CREDENTIAL_HUB = address(0);
}
