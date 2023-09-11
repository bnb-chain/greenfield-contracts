// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./storage/CmnStorage.sol";
import "../../interface/IApplication.sol";
import "../../interface/ICmnHub.sol";
import "../../interface/IERC721NonTransferable.sol";
import "../../interface/IMiddleLayer.sol";
import "../../lib/BytesToTypes.sol";

// DO NOT define any state variables in this contract.
abstract contract CmnHub is CmnStorage, Initializable, ICmnHub, IMiddleLayer {
    using DoubleEndedQueueUpgradeable for DoubleEndedQueueUpgradeable.Bytes32Deque;

    modifier noReentrant() {
        require(reentryLock != 2, "No Reentrant");
        reentryLock = 2;
        _;
        reentryLock = 1;
    }

    /*----------------- initializer -----------------*/
    function __cmn_hub_init(address _ERC721_token, address _additional) internal onlyInitializing {
        __cmn_hub_init_unchained(_ERC721_token, _additional);
    }

    function __cmn_hub_init_unchained(address _ERC721_token, address _additional) internal onlyInitializing {
        ERC721Token = _ERC721_token;
        additional = _additional;
    }

    function __cmn_hub_init_unchained_v2(uint256 _maxCallbackDataLength) internal onlyInitializing {
        maxCallbackDataLength = _maxCallbackDataLength;
    }

    /*----------------- middle-layer function -----------------*/
    // need to be implemented in child contract
    function handleSynPackage(uint8, bytes calldata) external virtual returns (bytes memory) {
        revert("not implemented");
    }

    function handleAckPackage(uint8, uint64, bytes calldata, uint256) external virtual returns (uint256, address) {
        revert("not implemented");
    }

    function handleFailAckPackage(uint8, uint64, bytes calldata, uint256) external virtual returns (uint256, address) {
        revert("not implemented");
    }

    /*----------------- external function -----------------*/
    function grant(address, uint32, uint256) external virtual {
        revert("not implemented");
    }

    function revoke(address, uint32) external virtual {
        revert("not implemented");
    }

    function retryPackage() external noReentrant {
        address appAddress = msg.sender;
        bytes32 pkgHash = retryQueue[appAddress].popFront();
        RetryPackage memory pkg = packageMap[pkgHash];
        delete packageMap[pkgHash];
        IApplication(pkg.appAddress).greenfieldCall(
            pkg.status,
            channelId,
            pkg.operationType,
            pkg.resourceId,
            pkg.callbackData
        );
    }

    function skipPackage() external {
        address appAddress = msg.sender;
        bytes32 pkgHash = retryQueue[appAddress].popFront();
        delete packageMap[pkgHash];
    }

    /*----------------- update param -----------------*/
    function updateParam(string calldata key, bytes calldata value) external virtual onlyGov {
        if (_compareStrings(key, "BaseURI")) {
            IERC721NonTransferable(ERC721Token).setBaseURI(string(value));
        } else if (_compareStrings(key, "AdditionalContract")) {
            require(value.length == 20, "length of additional address mismatch");
            address newAdditional = BytesToTypes.bytesToAddress(20, value);
            require(newAdditional != address(0) && _isContract(newAdditional), "additional address is not a contract");
            additional = newAdditional;
        } else if (_compareStrings(key, "MaxCallbackDataLength")) {
            require(value.length == 32, "length of maxCallbackDataLength mismatch");
            uint256 newMaxCallbackDataLength = BytesToTypes.bytesToUint256(32, value);
            require(newMaxCallbackDataLength > 0, "maxCallbackDataLength should be positive");
            maxCallbackDataLength = newMaxCallbackDataLength;
        } else {
            revert("unknown param");
        }
        emit ParamChange(key, value);
    }

    /*----------------- internal function -----------------*/
    function _handleCreateAckPackage(
        bytes memory pkgBytes,
        uint64 sequence,
        uint256 callbackGasLimit
    ) internal returns (uint256 remainingGas, address refundAddress) {
        CmnCreateAckPackage memory ackPkg = abi.decode(pkgBytes, (CmnCreateAckPackage));

        if (ackPkg.status == STATUS_SUCCESS) {
            _doCreate(ackPkg.creator, ackPkg.id);
        } else if (ackPkg.status == STATUS_FAILED) {
            emit CreateFailed(ackPkg.creator, ackPkg.id);
        } else {
            revert("unexpected status code");
        }

        if (ackPkg.extraData.length > 0) {
            ExtraData memory extraData = abi.decode(ackPkg.extraData, (ExtraData));

            if (extraData.appAddress != address(0) && callbackGasLimit >= 2300) {
                bytes memory reason;
                bool failed;
                uint256 gasBefore = gasleft();
                try
                    IApplication(extraData.appAddress).greenfieldCall{ gas: callbackGasLimit }(
                        ackPkg.status,
                        channelId,
                        TYPE_CREATE,
                        ackPkg.id,
                        extraData.callbackData
                    )
                {} catch Error(string memory error) {
                    reason = bytes(error);
                    failed = true;
                } catch (bytes memory lowLevelData) {
                    reason = lowLevelData;
                    failed = true;
                }

                uint256 gasUsed = gasBefore - gasleft();
                remainingGas = callbackGasLimit > gasUsed ? callbackGasLimit - gasUsed : 0;
                refundAddress = extraData.refundAddress;

                if (failed) {
                    bytes32 pkgHash = keccak256(abi.encodePacked(channelId, sequence));
                    emit AppHandleAckPkgFailed(extraData.appAddress, pkgHash, reason);
                    if (extraData.failureHandleStrategy != FailureHandleStrategy.SkipOnFail) {
                        packageMap[pkgHash] = RetryPackage(
                            extraData.appAddress,
                            ackPkg.status,
                            TYPE_CREATE,
                            ackPkg.id,
                            extraData.callbackData,
                            ""
                        );
                        retryQueue[extraData.appAddress].pushBack(pkgHash);
                    }
                }
            }
        }
    }

    function _doCreate(address creator, uint256 id) internal {
        IERC721NonTransferable(ERC721Token).mint(creator, id);
        emit CreateSuccess(creator, id);
    }

    function _handleDeleteAckPackage(
        bytes memory pkgBytes,
        uint64 sequence,
        uint256 callbackGasLimit
    ) internal returns (uint256 remainingGas, address refundAddress) {
        CmnDeleteAckPackage memory ackPkg = abi.decode(pkgBytes, (CmnDeleteAckPackage));

        if (ackPkg.status == STATUS_SUCCESS) {
            _doDelete(ackPkg.id);
        } else if (ackPkg.status == STATUS_FAILED) {
            emit DeleteFailed(ackPkg.id);
        } else {
            revert("unexpected status code");
        }

        if (ackPkg.extraData.length > 0) {
            ExtraData memory extraData = abi.decode(ackPkg.extraData, (ExtraData));

            if (extraData.appAddress != address(0) && callbackGasLimit >= 2300) {
                bytes memory reason;
                bool failed;
                uint256 gasBefore = gasleft();
                try
                    IApplication(extraData.appAddress).greenfieldCall{ gas: callbackGasLimit }(
                        ackPkg.status,
                        channelId,
                        TYPE_DELETE,
                        ackPkg.id,
                        extraData.callbackData
                    )
                {} catch Error(string memory error) {
                    reason = bytes(error);
                    failed = true;
                } catch (bytes memory lowLevelData) {
                    reason = lowLevelData;
                    failed = true;
                }

                uint256 gasUsed = gasBefore - gasleft();
                remainingGas = callbackGasLimit > gasUsed ? callbackGasLimit - gasUsed : 0;
                refundAddress = extraData.refundAddress;

                if (failed) {
                    bytes32 pkgHash = keccak256(abi.encodePacked(channelId, sequence));
                    emit AppHandleAckPkgFailed(extraData.appAddress, pkgHash, reason);
                    if (extraData.failureHandleStrategy != FailureHandleStrategy.SkipOnFail) {
                        packageMap[pkgHash] = RetryPackage(
                            extraData.appAddress,
                            ackPkg.status,
                            TYPE_DELETE,
                            ackPkg.id,
                            extraData.callbackData,
                            ""
                        );
                        retryQueue[extraData.appAddress].pushBack(pkgHash);
                    }
                }
            }
        }
    }

    function _doDelete(uint256 id) internal {
        IERC721NonTransferable(ERC721Token).burn(id);
        emit DeleteSuccess(id);
    }

    function _handleMirrorSynPackage(bytes calldata msgBytes) internal returns (bytes memory) {
        uint8 opType = uint8(msgBytes[0]);
        CmnMirrorSynPackage memory synPkg = abi.decode(msgBytes[1:], (CmnMirrorSynPackage));
        require(opType == TYPE_MIRROR, "wrong syn operation type");

        uint32 status = _doMirror(synPkg);
        CmnMirrorAckPackage memory mirrorAckPkg = CmnMirrorAckPackage({ status: status, id: synPkg.id });
        return abi.encodePacked(TYPE_MIRROR, abi.encode(mirrorAckPkg));
    }

    function _doMirror(CmnMirrorSynPackage memory synPkg) internal returns (uint32) {
        try IERC721NonTransferable(ERC721Token).mint(synPkg.owner, synPkg.id) {} catch Error(string memory error) {
            emit MirrorFailed(synPkg.id, synPkg.owner, bytes(error));
            return STATUS_FAILED;
        } catch (bytes memory lowLevelData) {
            emit MirrorFailed(synPkg.id, synPkg.owner, lowLevelData);
            return STATUS_FAILED;
        }
        emit MirrorSuccess(synPkg.id, synPkg.owner);
        return STATUS_SUCCESS;
    }

    function _handleDeleteFailAckPackage(
        bytes memory pkgBytes,
        uint64 sequence,
        uint256 callbackGasLimit
    ) internal returns (uint256 remainingGas, address refundAddress) {
        CmnDeleteSynPackage memory synPkg = abi.decode(pkgBytes, (CmnDeleteSynPackage));

        if (synPkg.extraData.length > 0) {
            ExtraData memory extraData = abi.decode(synPkg.extraData, (ExtraData));

            if (extraData.appAddress != address(0) && callbackGasLimit >= 2300) {
                bytes memory reason;
                bool failed;
                uint256 gasBefore = gasleft();
                try
                    IApplication(extraData.appAddress).greenfieldCall{ gas: callbackGasLimit }(
                        STATUS_UNEXPECTED,
                        channelId,
                        TYPE_DELETE,
                        synPkg.id,
                        extraData.callbackData
                    )
                {} catch Error(string memory error) {
                    reason = bytes(error);
                    failed = true;
                } catch (bytes memory lowLevelData) {
                    reason = lowLevelData;
                    failed = true;
                }

                uint256 gasUsed = gasBefore - gasleft();
                remainingGas = callbackGasLimit > gasUsed ? callbackGasLimit - gasUsed : 0;
                refundAddress = extraData.refundAddress;

                if (failed) {
                    bytes32 pkgHash = keccak256(abi.encodePacked(channelId, sequence));
                    emit AppHandleAckPkgFailed(extraData.appAddress, pkgHash, reason);
                    if (extraData.failureHandleStrategy != FailureHandleStrategy.SkipOnFail) {
                        packageMap[pkgHash] = RetryPackage(
                            extraData.appAddress,
                            STATUS_UNEXPECTED,
                            TYPE_DELETE,
                            synPkg.id,
                            extraData.callbackData,
                            ""
                        );
                        retryQueue[extraData.appAddress].pushBack(pkgHash);
                    }
                }
            }
        }
    }

    function delegateAdditional() internal {
        address _target = additional;
        assembly {
            // The pointer to the free memory slot
            let ptr := mload(0x40)
            // Copy function signature and arguments from calldata at zero position into memory at pointer position
            calldatacopy(ptr, 0x0, calldatasize())
            // Delegatecall method of the implementation contract, returns 0 on error
            let result := delegatecall(gas(), _target, ptr, calldatasize(), 0x0, 0)
            // Get the size of the last return data
            let size := returndatasize()
            // Copy the size length of bytes from return data at zero position to pointer position
            returndatacopy(ptr, 0x0, size)

            // Depending on result value
            switch result
            case 0 {
                // End execution and revert state changes
                revert(ptr, size)
            }
            default {
                // Return data with length of size at pointers position
                return(ptr, size)
            }
        }
    }
}
