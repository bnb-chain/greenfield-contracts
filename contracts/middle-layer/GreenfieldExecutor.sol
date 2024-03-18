// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../Config.sol";
import "../interface/ICrossChain.sol";
import "../interface/IGreenfieldExecutor.sol";

contract GreenfieldExecutor is Config, Initializable, IGreenfieldExecutor {
    constructor() {
        _disableInitializers();
    }
    function initialize() public initializer {}

    function execute(bytes[] calldata _data) external payable override returns (bool) {
        uint256 _length = _data.length;
        require(_length > 0, "empty data");

        (uint256 relayFee, ) = ICrossChain(CROSS_CHAIN).getRelayFees();
        require(msg.value == (relayFee * _length), "not enough value");

        // generate packages
        bytes[] memory messages = new bytes[](_data.length);
        for (uint256 i = 0; i < _length; ++i) {
            messages[i] = abi.encode(_data[i], msg.sender);
        }

        // send sync package
        ICrossChain(CROSS_CHAIN).sendSynPackage(GNFD_EXECUTOR_CHANNEL_ID, abi.encode(messages), msg.value, 0);

        return true;
    }

    function versionInfo()
        external
        pure
        override
        returns (uint256 version, string memory name, string memory description)
    {
        return (1_000_001, "GreenfieldExecutor", "init");
    }
}
