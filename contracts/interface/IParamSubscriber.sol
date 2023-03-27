// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

interface IParamSubscriber {
    function updateParam(string calldata key, bytes calldata value) external;
}
