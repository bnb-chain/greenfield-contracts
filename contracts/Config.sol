// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "./interface/ILightClient.sol";

abstract contract Config {
    uint8 public constant TRANSFER_IN_CHANNEL_ID = 0x01;
    uint8 public constant TRANSFER_OUT_CHANNEL_ID = 0x02;
    uint8 public constant GOV_CHANNELID = 0x03;

    uint32 public constant CODE_OK = 0;
    uint32 public constant ERROR_FAIL_DECODE = 100;

    // contract address
    // will calculate their deployed addresses from deploy script
    address public constant PROXY_ADMIN = 0x36561B3f082144418fec9Ae4Fc56Cb1cA635ea7f;
    address public constant GOV_HUB = 0xc9eFd493fbB405a02487Cf56017a9d0fE1692AFB;
    address public constant CROSS_CHAIN = 0xBB8086f99120Cd2e955908D3857Ec1659b3Dc3a9;
    address public constant TOKEN_HUB = 0x48D920D4E0d75EC70d87470318851323947a4ECA;
    address public constant LIGHT_CLIENT = 0x0D4082f97F99AB789E552084f9991985C6EAC31B;
    address public constant RELAYER_HUB = 0x34a5d1287F681c150EEc0C85e5C0e177A4f934DE;


    modifier onlyCrossChain() {
        require(msg.sender == CROSS_CHAIN, "only CrossChain contract");
        _;
    }

    modifier onlyGov() {
        require(msg.sender == GOV_HUB, "only GovHub contract");
        _;
    }

    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function upgradeInfo() external pure virtual returns (uint256 version, string memory name, string memory description) {
        return (0, "Config", "");
    }
}
