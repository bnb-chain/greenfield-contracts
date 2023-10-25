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
    address public constant PROXY_ADMIN = 0x9CFAFbDAB8F2e86a8a27029A5E77b2534457BeD6;
    address public constant GOV_HUB = 0x5c5a4AA1ee2685e13EB36697088852c328d14F79;
    address public constant CROSS_CHAIN = 0x9B95D20589055c13cD0c298C3a8D20895e9F1dA0;
    address public constant TOKEN_HUB = 0x8a470e6C8fd3fE14b3E56681Bc59927Ca8E3a667;
    address public constant LIGHT_CLIENT = 0x418E4adC42e6CAb02B2281d8178622A16f4c9d4d;
    address public constant RELAYER_HUB = 0xE1f1439364F1f666E72E63f3a7Db9388016E2db6;
    address public constant BUCKET_HUB = 0xc48BC04097224c9Cd0eb42D75D706EdA57FFD83E;
    address public constant OBJECT_HUB = 0x12EBd3286791970BBdaCD11dba296596c1DB52dE;
    address public constant GROUP_HUB = 0x1Ff260e40F4991D4351341352aD39086ab5d460b;
    address public constant EMERGENCY_OPERATOR = 0x4765b1382B1a7C88EF8566A8B8386F15528dB3dA;
    address public constant EMERGENCY_UPGRADE_OPERATOR = 0x4870829F800997B1fc6E519A4143956D7e290dd3;

    // PlaceHolder reserve for future usage
    uint256[50] private configSlots;

    modifier onlyCrossChain() {
        require(msg.sender == CROSS_CHAIN, "only CrossChain contract");
        _;
    }

    modifier onlyGov() {
        require(msg.sender == GOV_HUB, "only GovHub contract");
        _;
    }

    modifier onlyEmergencyOperator() {
        require(msg.sender == EMERGENCY_OPERATOR, "only Emergency Operator");
        _;
    }

    modifier onlyEmergencyUpgradeOperator() {
        require(msg.sender == EMERGENCY_UPGRADE_OPERATOR, "only Emergency Upgrade Operator");
        _;
    }

    function _compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
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
