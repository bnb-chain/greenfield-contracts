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
    address public constant PROXY_ADMIN = 0xfBD745797A0fb50429f0a2b04581092798Fdf30B;
    address public constant GOV_HUB = 0x8Ba41269ed69496c07bea886c300016A0BA8FB5E;
    address public constant CROSS_CHAIN = 0xe7942Ac9b02c9e668f795F73f32D719462c5fF08;
    address public constant TOKEN_HUB = 0xB171D866832A106B680c555EE020De47fD62cae1;
    address public constant LIGHT_CLIENT = 0xB893a52711b3676A1c648ccCfE071FD3622f627e;
    address public constant RELAYER_HUB = 0xc261BC4A12b8a85694ff49002Eee1D6583d0AeDF;
}
