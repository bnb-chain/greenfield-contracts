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
    address public constant PROXY_ADMIN = 0xcd5D019b3C5AeD679995ed94ba7D352Cc1500b7C;
    address public constant GOV_HUB = 0xCa05b30aF093bD38c3AfEA56812a5FA21150592F;
    address public constant CROSS_CHAIN = 0x5C7e42a885Fd9Aee902476ff6AE16b00cE41eA2c;
    address public constant TOKEN_HUB = 0x05f362cF99109B54C08045bB4DA535D387A8B330;
    address public constant LIGHT_CLIENT = 0x0101Ba65864b431Da46c96A572A4c1d3e3d353Ba;
    address public constant RELAYER_HUB = 0xcBeAcB2DC22629B65Cfd108033c4E3852d6E89F0;
    address public constant CREDENTIAL_HUB = 0xbE3898BC2D1222084192136F47b432e06cc20724;
}
