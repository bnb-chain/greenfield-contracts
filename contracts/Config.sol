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
    uint8 public constant PERMISSION_CHANNEL_ID = 0x07;

    // contract address
    // will calculate their deployed addresses from deploy script
    address public constant PROXY_ADMIN = 0x212fdfCfCC22db97DeB3AC3260414909282BB4EE;
    address public constant GOV_HUB = 0xDa1A2E33BD9E8ae3641A61ab72f137e61A7edf6e;
    address public constant CROSS_CHAIN = 0x2DB9DB0187fb40BA1b266Ee19cEb901fba8231fE;
    address public constant TOKEN_HUB = 0x68923513DEEE122f411DAFC42c9CF86Ca3d230e7;
    address public constant LIGHT_CLIENT = 0x48be4A7C7Ac4BA704A9598B491216b1A9C1f3d2C;
    address public constant RELAYER_HUB = 0x3148Bf33f02b445db31439934D920eE8f67E2558;
    address public constant BUCKET_HUB = 0x2953ed386ae431B0f95235e0319a0a4a0a57F1d2;
    address public constant OBJECT_HUB = 0xF2C91c75484B319c377307a3C11AE56312563beA;
    address public constant GROUP_HUB = 0x74f4e91904e1c193C9FE878997105ce0bB993b0d;
    address public constant EMERGENCY_OPERATOR = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public constant EMERGENCY_UPGRADE_OPERATOR = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public constant PERMISSION_HUB = 0x6b514677e8d86700bd42a755f7BB47F6A31244a7;

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
