pragma solidity ^0.8.0;

contract Config {
    uint8 constant public VALIDATORSET_CHANNELID = 0x01;
    uint8 constant public APP_CHANNELID = 0x02;
    uint8 constant public TRANSFER_IN_CHANNELID = 0x03;
    uint8 constant public TRANSFER_OUT_CHANNELID = 0x04;


    address public CROSS_CHAIN_CONTRACT_ADDR;


    modifier onlyCrossChainContract() {
        // TODO
        _;
    }

    modifier onlyGov() {
        // TODO
        _;
    }

    modifier onlyTokenManager() {
        // TODO
        _;
    }

    modifier onlyRelayer() {
        // TODO
        _;
    }
}
