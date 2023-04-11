// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "./interface/ILightClient.sol";

abstract contract Config {
    uint8 public constant TRANSFER_IN_CHANNEL_ID = 0x01;
    uint8 public constant TRANSFER_OUT_CHANNEL_ID = 0x02;
    uint8 public constant GOV_CHANNEL_ID = 0x03;
    uint8 public constant BUCKET_CHANNEL_ID = 0x04;
    uint8 public constant OBJECT_CHANNEL_ID = 0x05;
    uint8 public constant GROUP_CHANNEL_ID = 0x06;

    // contract address
    // will calculate their deployed addresses from deploy script
    address public constant PROXY_ADMIN = 0xa16E02E87b7454126E5E10d957A927A7F5B5d2be;
    address public constant GOV_HUB = 0xB7A5bd0345EF1Cc5E66bf61BdeC17D2461fBd968;
    address public constant CROSS_CHAIN = 0xeEBe00Ac0756308ac4AaBfD76c05c4F3088B8883;
    address public constant TOKEN_HUB = 0x10C6E9530F1C1AF873a391030a1D9E8ed0630D26;
    address public constant LIGHT_CLIENT = 0x603E1BD79259EbcbAaeD0c83eeC09cA0B89a5bcC;
    address public constant RELAYER_HUB = 0x86337dDaF2661A069D0DcB5D160585acC2d15E9a;
    address public constant BUCKET_HUB = 0x9CfA6D15c80Eb753C815079F2b32ddEFd562C3e4;
    address public constant OBJECT_HUB = 0x427f7c59ED72bCf26DfFc634FEF3034e00922DD8;
    address public constant GROUP_HUB = 0x275039fc0fd2eeFac30835af6aeFf24e8c52bA6B;

    // PlaceHolder reserve for future usage
    uint256[50] public ConfigSlots;

    modifier onlyCrossChain() {
        require(msg.sender == CROSS_CHAIN, "only CrossChain contract");
        _;
    }

    modifier onlyGov() {
        require(msg.sender == GOV_HUB, "only GovHub contract");
        _;
    }

    // Please note this is a weak check, don't use this when you need a strong verification.
    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function versionInfo()
        external
        pure
        virtual
        returns (uint256 version, string memory name, string memory description)
    {
        return (0, "Config", "");
    }
}
