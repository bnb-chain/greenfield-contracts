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
    address public constant PROXY_ADMIN = 0xc95ff0608561b6bA084c78D14f09e9826190f968;
    address public constant GOV_HUB = 0xbD89b434dD59562756ED9B14B0bec5E71f3c6876;
    address public constant CROSS_CHAIN = 0xB01718DCF2124e3a9217aC0dEc176a72733d2589;
    address public constant TOKEN_HUB = 0x6E7A80364c02f6DA5A656a753ef77d9AF1aEFdCE;
    address public constant LIGHT_CLIENT = 0xa2D02d5ef64883cE9DECE061Aa56eDfd0A32219a;
    address public constant RELAYER_HUB = 0x7e7e5FB7349Be2CFD6dBF90Ae55279F6C3Bf0887;
    address public constant BUCKET_HUB = 0x1417A5F39e851007bAAd5Ba06C0C66117151D34c;
    address public constant OBJECT_HUB = 0xBe16A8c062C188E581000C367d5bdCbd58Df1034;
    address public constant GROUP_HUB = 0x45860344720176c89A99dcACce8775Bcca1b7047;

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
