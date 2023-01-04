pragma solidity ^0.8.0;
import "./interface/ILightClient.sol";

abstract contract Config {
    uint8 constant public VALIDATORSET_CHANNELID = 0x01;
    uint8 constant public APP_CHANNELID = 0x02;
    uint8 constant public TRANSFER_IN_CHANNELID = 0x03;
    uint8 constant public TRANSFER_OUT_CHANNELID = 0x04;

    // TODO
    address constant public CROSS_CHAIN_CONTRACT_ADDR = 0x0000000000000000000000000000000000003000;
    address constant public INSCRIPTION_LIGHT_CLIENT_ADDR = 0x0000000000000000000000000000000000003001;
    address constant public TOKEN_HUB_ADDR = 0x0000000000000000000000000000000000003002;

    uint32 public constant CODE_OK = 0;
    uint32 public constant ERROR_FAIL_DECODE = 100;

    modifier onlyCrossChainContract() {
        require(msg.sender == CROSS_CHAIN_CONTRACT_ADDR, "only cross chain contract");
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

    modifier onlyRelayers() {
        bool isRelayer;
        address[] memory relayers = ILightClient(INSCRIPTION_LIGHT_CLIENT_ADDR).getRelayers();
        uint256 _totalRelayers = relayers.length;
        require(_totalRelayers > 0, "empty relayers");
        for (uint256 i = 0; i < _totalRelayers; i++) {
            if (relayers[i] == msg.sender) {
                isRelayer = true;
                break;
            }
        }
        require(isRelayer, "only relayer");

        _;
    }
}
