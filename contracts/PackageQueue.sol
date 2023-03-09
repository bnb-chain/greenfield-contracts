// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/structs/DoubleEndedQueueUpgradeable.sol";

import "./interface/IApplication.sol";

contract PackageQueue {
    using DoubleEndedQueueUpgradeable for DoubleEndedQueueUpgradeable.Bytes32Deque;

    uint8 public channelId;

    // app address => FailureHandleStrategy
    mapping(address => FailureHandleStrategy) public failureHandleMap;
    // app address => retry queue of package hash
    mapping(address => DoubleEndedQueueUpgradeable.Bytes32Deque) public retryQueue;
    // app retry package hash => retry package
    mapping(bytes32 => RetryPackage) public packageMap;

    enum FailureHandleStrategy {
        Closed, // any dapp must register its failure strategy first or the status will be closed
        HandleInOrder, // ack package must be handled in order and dapp cannot send new syn package without handling all failed ack package
        Cache, // failed ack package will be cached and dapp can send new syn package without handling all failed ack package
        Skip // failed ack package will be skipped
    }

    struct RetryPackage {
        address appAddress;
        bytes msgBytes;
        bytes callbackData;
        bool isFailAck;
        bytes failReason;
    }

    event AppHandleAckPkgFailed(address indexed appAddress, bytes32 pkgHash, bytes failReason);
    event AppHandleFailAckPkgFailed(address indexed appAddress, bytes32 pkgHash, bytes failReason);

    modifier onlyPackageNotDeleted(bytes32 pkgHash) {
        require(packageMap[pkgHash].appAddress != address(0), "package already deleted");
        _;
    }

    modifier checkFailureStrategy(bytes32 pkgHash) {
        address appAddress = msg.sender;
        require(failureHandleMap[appAddress] != FailureHandleStrategy.Closed, "strategy not allowed");
        require(packageMap[pkgHash].appAddress == appAddress, "invalid caller");
        if (failureHandleMap[appAddress] == FailureHandleStrategy.HandleInOrder) {
            require(retryQueue[appAddress].popFront() == pkgHash, "package not on front");
        }
        _;
    }

    function setFailureHandleStrategy(FailureHandleStrategy _strategy) external {
        failureHandleMap[msg.sender] = _strategy;
    }

    function retryPackage(bytes32 pkgHash) external onlyPackageNotDeleted(pkgHash) checkFailureStrategy(pkgHash) {
        address appAddress = msg.sender;
        bytes memory _msgBytes = packageMap[pkgHash].msgBytes;
        bytes memory _callbackData = packageMap[pkgHash].callbackData;
        if (packageMap[pkgHash].isFailAck) {
            IApplication(appAddress).handleFailAckPackage(channelId, _msgBytes, _callbackData);
        } else {
            IApplication(appAddress).handleAckPackage(channelId, _msgBytes, _callbackData);
        }
        delete packageMap[pkgHash];
        _cleanQueue(appAddress);
    }

    function skipPackage(bytes32 pkgHash) external onlyPackageNotDeleted(pkgHash) checkFailureStrategy(pkgHash) {
        delete packageMap[pkgHash];
        _cleanQueue(msg.sender);
    }

    /*----------------- Internal functions -----------------*/
    function _cleanQueue(address appAddress) internal {
        DoubleEndedQueueUpgradeable.Bytes32Deque storage _queue = retryQueue[appAddress];
        bytes32 _front;
        while (!_queue.empty()) {
            _front = _queue.front();
            if (packageMap[_front].appAddress != address(0)) {
                break;
            }
            _queue.popFront();
        }
    }
}
