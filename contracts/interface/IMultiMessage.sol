// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "../middle-layer/resource-mirror/storage/MultiStorage.sol";

interface IMultiMessage {
    function sendMessages(
        address[] calldata _targets,
        bytes[] calldata _data,
        uint256[] calldata _values
    ) external payable returns (bool);
}
