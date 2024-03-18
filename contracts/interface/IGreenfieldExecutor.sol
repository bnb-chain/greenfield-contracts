// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

interface IGreenfieldExecutor {
    function execute(bytes[] calldata _data) external payable returns (bool);
}
