// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/structs/DoubleEndedQueueUpgradeable.sol";

import "./interface/IApplication.sol";

contract PackageQueue {
    using DoubleEndedQueueUpgradeable for DoubleEndedQueueUpgradeable.Bytes32Deque;

    uint8 public channelId;

    // app address => retry queue of package hash
    mapping(address => DoubleEndedQueueUpgradeable.Bytes32Deque) public retryQueue;
    // app retry package hash => retry package
    mapping(bytes32 => RetryPackage) public packageMap;

    /**
     * An enum representing the strategies for handling failed ACK packages.
     */
    enum FailureHandleStrategy {
        HandleInSequence, // Handle failed ACK packages in the order they were received. Noted that new syn packages will be blocked until all failed ACK packages are handled.
        CacheUntilReady, // Cache failed ACK packages until the dapp is ready to handle them. New syn packages will be handled normally.
        SkipAckPackage // Simply ignore the failed ACK package
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
        require(packageMap[pkgHash].appAddress == appAddress, "invalid caller");
        require(retryQueue[appAddress].popFront() == pkgHash, "package not on front");
        _;
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
        _popFront(appAddress);
    }

    function skipPackage(bytes32 pkgHash) external onlyPackageNotDeleted(pkgHash) checkFailureStrategy(pkgHash) {
        delete packageMap[pkgHash];
        _popFront(msg.sender);
    }

    /*----------------- Internal functions -----------------*/
    function _popFront(address appAddress) internal {
        DoubleEndedQueueUpgradeable.Bytes32Deque storage _queue = retryQueue[appAddress];
        bytes32 _front;
        if (!_queue.empty()) {
            _front = _queue.front();
            if (packageMap[_front].appAddress != address(0)) {
                return;
            }
            _queue.popFront();
        }
    }
}
