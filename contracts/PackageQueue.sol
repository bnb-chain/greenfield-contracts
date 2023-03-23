// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/structs/DoubleEndedQueueUpgradeable.sol";

import "./interface/IApplication.sol";

contract PackageQueue {
    using DoubleEndedQueueUpgradeable for DoubleEndedQueueUpgradeable.Bytes32Deque;

    uint8 public channelId;

    // app address => retry queue of package hash
    mapping(address => DoubleEndedQueueUpgradeable.Bytes32Deque) public retryQueue;
    // app retry package hash => retry package
    mapping(bytes32 => CallbackPackage) public packageMap;

    /*
     * This enum provides different strategies for handling a failed ACK package.
     */
    enum FailureHandleStrategy {
        BlockOnFail, // If a package fails, the subsequent SYN packages will be blocked until the failed ACK packages are handled in the order they were received.
        CacheOnFail, // When a package fails, it is cached for later handling. New SYN packages will continue to be handled normally.
        SkipOnFail // Failed ACK packages are ignored and will not affect subsequent SYN packages.
    }

    struct CallbackPackage {
        address appAddress;
        bytes msgBytes;
        bytes callbackData;
        bool isFailAck;
        bytes failReason;
    }

    event AppHandleAckPkgFailed(address indexed appAddress, bytes32 pkgHash, bytes failReason);
    event AppHandleFailAckPkgFailed(address indexed appAddress, bytes32 pkgHash, bytes failReason);

    // PlaceHolder reserve for future usage
    uint256[50] public PkgQueueSlots;

    modifier checkCaller() {
        address appAddress = msg.sender;
        bytes32 pkgHash = retryQueue[appAddress].front();
        require(packageMap[pkgHash].appAddress == appAddress, "invalid caller");
        _;
    }

    function retryPackage() external checkCaller {
        address appAddress = msg.sender;
        bytes32 pkgHash = retryQueue[appAddress].popFront();
        bytes memory _msgBytes = packageMap[pkgHash].msgBytes;
        bytes memory _callbackData = packageMap[pkgHash].callbackData;
        if (packageMap[pkgHash].isFailAck) {
            IApplication(appAddress).handleFailAckPackage(channelId, _msgBytes, _callbackData);
        } else {
            IApplication(appAddress).handleAckPackage(channelId, _msgBytes, _callbackData);
        }
        delete packageMap[pkgHash];
    }

    function skipPackage() external checkCaller {
        address appAddress = msg.sender;
        bytes32 pkgHash = retryQueue[appAddress].popFront();
        delete packageMap[pkgHash];
    }
}
