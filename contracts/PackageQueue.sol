// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/structs/DoubleEndedQueueUpgradeable.sol";

import "./interface/IApplication.sol";

contract PackageQueue {
    using DoubleEndedQueueUpgradeable for DoubleEndedQueueUpgradeable.Bytes32Deque;

    uint256 public constant CALLBACK_GAS_LIMIT = 100000; // TODO use constant for now

    uint8 public channelId;

    // app address => FailureHandleStrategy
    mapping(address => FailureHandleStrategy) public failureHandleMap;
    // app address => retry queue of package hash
    mapping(address => DoubleEndedQueueUpgradeable.Bytes32Deque) public retryQueue;
    // app retry package hash => retry package
    mapping(bytes32 => RetryPackage) public packageMap;

    enum FailureHandleStrategy {
        Closed, // any dapp must register its failure strategy first
        HandleInOrder,
        Cache,
        Skip,
        NoCallBack
    }

    struct RetryPackage {
        address appAddress;
        bytes msgBytes;
        bytes callBackData;
        bool isFailAck;
        bytes failReason;
    }

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
        bytes memory _callBackData = packageMap[pkgHash].callBackData;
        if (packageMap[pkgHash].isFailAck) {
            IApplication(appAddress).handleFailAckPackage{gas: CALLBACK_GAS_LIMIT}(channelId, _msgBytes, _callBackData);
        } else {
            IApplication(appAddress).handleAckPackage{gas: CALLBACK_GAS_LIMIT}(channelId, _msgBytes, _callBackData);
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
