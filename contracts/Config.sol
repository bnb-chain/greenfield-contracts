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
    address public constant PROXY_ADMIN = 0xa16E02E87b7454126E5E10d957A927A7F5B5d2be;
    address public constant GOV_HUB = 0xB7A5bd0345EF1Cc5E66bf61BdeC17D2461fBd968;
    address public constant CROSS_CHAIN = 0xeEBe00Ac0756308ac4AaBfD76c05c4F3088B8883;
    address public constant TOKEN_HUB = 0x10C6E9530F1C1AF873a391030a1D9E8ed0630D26;
    address public constant LIGHT_CLIENT = 0x603E1BD79259EbcbAaeD0c83eeC09cA0B89a5bcC;
    address public constant RELAYER_HUB = 0x86337dDaF2661A069D0DcB5D160585acC2d15E9a;
}
