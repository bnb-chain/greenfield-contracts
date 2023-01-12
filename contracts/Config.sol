pragma solidity ^0.8.0;
import "./interface/ILightClient.sol";

abstract contract Config {
    uint8 constant public VALIDATORSET_CHANNELID = 0x01;
    uint8 constant public APP_CHANNELID = 0x02;
    uint8 constant public TRANSFER_IN_CHANNELID = 0x03;
    uint8 constant public TRANSFER_OUT_CHANNELID = 0x04;
    uint8 constant public GOV_CHANNELID = 0x05;

    uint32 public constant CODE_OK = 0;
    uint32 public constant ERROR_FAIL_DECODE = 100;
}
