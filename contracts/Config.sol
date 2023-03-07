// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "./interface/ILightClient.sol";

abstract contract Config {
    uint8 public constant TRANSFER_IN_CHANNEL_ID = 0x01;
    uint8 public constant TRANSFER_OUT_CHANNEL_ID = 0x02;
    uint8 public constant APP_CHANNEL_ID = 0x03;
    uint8 public constant GOV_CHANNEL_ID = 0x05;

    // TODO channel ID
    uint8 public constant BUCKET_CHANNEL_ID = 0x06;
    uint8 public constant OBJECT_CHANNEL_ID = 0x07;
    uint8 public constant GROUP_CHANNEL_ID = 0x08;

    // contract address
    // will calculate their deployed addresses from deploy script
    address public constant PROXY_ADMIN = 0x5c5C6172fAc28db4b4537a7f76D58114bE594D3c;
    address public constant GOV_HUB = 0x804CC502e243b70540385be483522A8A7D608B2A;
    address public constant CROSS_CHAIN = 0x57afd3Bf138F12d3e7d287Aa96fbf1f527638b6c;
    address public constant TOKEN_HUB = 0x769B89C9f01E39e89d14868b87DCE2983912Ed4F;
    address public constant LIGHT_CLIENT = 0xE52D879f47D71305569a988f36bD2F381CB97F3F;
    address public constant RELAYER_HUB = 0x0df3CeEFa4C8855392A820423C22DD38FdE3452c;
    address public constant BUCKET_HUB = 0x5277d11e3Dc95b9C68702c869C5e02076cCc27df;
    address public constant OBJECT_HUB = 0x38170e762B44FF70b2D6A4C260BFdCa487114D22;
    address public constant GROUP_HUB = 0xDacea477C53FDfE44B30F5FAF16CC2686736209F;

    // relayer
    uint256 public relayFee;
    uint256 public ackRelayFee;

    uint256 public callbackGasPrice;
    uint256 public transferGas;
}
