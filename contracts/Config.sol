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
    uint8 public constant MULTI_MESSAGE_CHANNEL_ID = 0x08;
    uint8 public constant GNFD_EXECUTOR_CHANNEL_ID = 0x09;

    /**
     * @dev The eip-2771 defines a contract-level protocol for Recipient contracts to accept
     * meta-transactions through trusted Forwarder contracts. No protocol changes are made.
     * Recipient contracts are sent the effective msg.sender (referred to as _msgSender())
     * and msg.data (referred to as _msgData()) by appending additional calldata.
     * eip-2771 doc: https://eips.ethereum.org/EIPS/eip-2771
     * openzeppelin eip-2771 contract: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/metatx/ERC2771Forwarder.sol
     * The ERC2771_FORWARDER contract deployed from: https://github.com/bnb-chain/ERC2771Forwarder.git
     */
    address public constant ERC2771_FORWARDER = 0x5e06E40B2c35157AE1ba0a63e2371a34EB8Bde8b;

    // contract address
    // will calculate their deployed addresses from deploy script
    address public constant PROXY_ADMIN = 0xB028Aeff726B6224D2af9F261DfCd5f064206773;
    address public constant GOV_HUB = 0x8192a6eE35b223AbfDB3AaAB93d06F0B5F5c5F34;
    address public constant CROSS_CHAIN = 0x76D7e4dE580C15087c09085E766335cdb93601a5;
    address public constant TOKEN_HUB = 0xe1feAbDa7051dB60F990229d77eb5Ba04aDB301C;
    address public constant LIGHT_CLIENT = 0x1C0D0f790F6C032A87991Ad08F7BbE1d2b29b974;
    address public constant RELAYER_HUB = 0x3Ea2dce61C14FE52EeE766Ab5cf996a869Bee8a4;
    address public constant BUCKET_HUB = 0x93bB122136839Ba8aD9eaeE038FA8f6eF8dfA592;
    address public constant OBJECT_HUB = 0xd0BDe4e613632F6e292427873dBcD857c469f8e9;
    address public constant GROUP_HUB = 0xd7dE3f38f192C32Dd04d0d774D9db43f190afA8E;
    address public constant EMERGENCY_OPERATOR = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public constant EMERGENCY_UPGRADE_OPERATOR = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public constant PERMISSION_HUB = 0x6edf5443ED7135f42f38868565189d9796E46564;
    address public constant MULTI_MESSAGE = 0x60E8e8437637a33D5EfAB3cFbA1778CEC443271A;
    address public constant GNFD_EXECUTOR = 0x522cAb29d30faf35C6730af9563Ea61dbB58344D;

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

    modifier onlyMultiMessage() {
        require(msg.sender == MULTI_MESSAGE, "only multiMessage");
        _;
    }

    function _compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    // Please note this is a weak check, don't use this when you need a strong verification.
    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    /**
     * @dev Override for `msg.sender`. Defaults to the original `msg.sender` whenever
     * a call is not performed by the trusted forwarder or the calldata length is less than
     * 20 bytes (an address length).
     */
    function _erc2771Sender() internal view returns (address) {
        uint256 calldataLength = msg.data.length;
        uint256 contextSuffixLength = _contextSuffixLength();
        if (isTrustedForwarder(msg.sender) && calldataLength >= contextSuffixLength) {
            return address(bytes20(msg.data[calldataLength - contextSuffixLength:]));
        } else {
            return msg.sender;
        }
    }

    function isTrustedForwarder(address forwarder) public pure returns (bool) {
        return forwarder == ERC2771_FORWARDER;
    }

    /**
     * @dev ERC-2771 specifies the context as being a single address (20 bytes).
     */
    function _contextSuffixLength() internal pure returns (uint256) {
        return 20;
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
