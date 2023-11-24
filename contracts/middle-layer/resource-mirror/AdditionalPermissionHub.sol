// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/DoubleEndedQueueUpgradeable.sol";

import "./storage/PermissionStorage.sol";
import "../../interface/IApplication.sol";
import "../../interface/ICrossChain.sol";
import "../../interface/IERC721NonTransferable.sol";

// Highlight: This contract must have the same storage layout as PermissionHub
// which means same state variables and same order of state variables.
// Because it will be used as a delegate call target.
// NOTE: The inherited contracts order must be the same as PermissionHub.
contract AdditionalPermissionHub is PermissionStorage {
    // PlaceHolder corresponding to `Initializable` contract
    uint8 private _initialized;
    bool private _initializing;

    using DoubleEndedQueueUpgradeable for DoubleEndedQueueUpgradeable.Bytes32Deque;
}
