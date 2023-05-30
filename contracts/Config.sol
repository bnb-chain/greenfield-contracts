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
    address public constant PROXY_ADMIN = 0x052008988d3b1023599aa61A852bf1c06b776159;
    address public constant GOV_HUB = 0xA8F0692E97B3e4C3fa7baa2982540A68a015Eb2A;
    address public constant CROSS_CHAIN = 0x24e4b644DF338f9656843E2Ebf1b84715B8c58Ba;
    address public constant TOKEN_HUB = 0xf5192b167d11ed87C02123801c0305ef072df04F;
    address public constant LIGHT_CLIENT = 0xdaE85fF84e36922Bb822aE90894Bc9E5B7a128cE;
    address public constant RELAYER_HUB = 0xF04cC2EF918C84E69e673d50f2b6BFac4B9F47Ff;
    address public constant BUCKET_HUB = 0x1E2D9D372e51435c63a95cd934C9bcE1b6e32381;
    address public constant OBJECT_HUB = 0x969bF7f9C9Cc43515c1448ca4f99369e4FDf65B3;
    address public constant GROUP_HUB = 0x014964f4596A1fE218867867696b0661cF2421CA;

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
