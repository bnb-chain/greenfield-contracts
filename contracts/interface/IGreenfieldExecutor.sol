// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

interface IGreenfieldExecutor {
    function execute(uint8[] calldata _msgTypes, bytes[] calldata _msgBytes) external payable returns (bool);
}
