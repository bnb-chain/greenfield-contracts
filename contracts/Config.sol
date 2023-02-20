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
    address public constant PROXY_ADMIN = 0x58c864b50A4E0767216cfC9730E78FE6eA497Ddc;
    address public constant GOV_HUB = 0xa90578492aeA3aB45c2D3E5f7f94fF1eac0Add2A;
    address public constant CROSS_CHAIN = 0x4739c3fAbd570E3dc1d18fEF48D07f09c3617adC;
    address public constant TOKEN_HUB = 0x330F6480992D8F31e490764Ef7329962f13086Cc;
    address public constant LIGHT_CLIENT = 0xCf5928aAF8fD48515100d56c56795fb1770eCaD8;
    address public constant RELAYER_HUB = 0x02Ce742EB11Ba583aBfd82757222963da645DF67;
    address public constant CREDENTIAL_HUB = 0x74c3857491DD9ca7F367a3A65d6F654B83b3d4Db;
}
