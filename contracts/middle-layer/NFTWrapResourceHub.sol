// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./NFTWrapResourceStorage.sol";
import "../lib/BytesToTypes.sol";
import "../lib/Memory.sol";
import "../lib/RLPDecode.sol";
import "../lib/RLPEncode.sol";
import "../interface/IAccessControl.sol";
import "../interface/IApplication.sol";
import "../interface/IERC721NonTransferable.sol";

// DO NOT define any state variables in this contract.
abstract contract NFTWrapResourceHub is NFTWrapResourceStorage, Initializable {
    using DoubleEndedQueueUpgradeable for DoubleEndedQueueUpgradeable.Bytes32Deque;
    using RLPEncode for *;
    using RLPDecode for *;

    /*----------------- modifier -----------------*/
    modifier onlyGovHub() {
        require(msg.sender == GOV_HUB, "only GovHub contract");
        _;
    }

    /*----------------- middle-layer function -----------------*/
    // need to be implemented in child contract
    function handleSynPackage(uint8 channelId, bytes calldata callbackData) external virtual returns (bytes memory) {}

    function handleAckPackage(
        uint8 channelId,
        uint64 sequence,
        bytes calldata callbackData,
        uint256 callbackGasLimit
    ) external virtual returns (uint256 remainingGas, address refundAddress) {}

    function handleFailAckPackage(
        uint8 channelId,
        uint64 sequence,
        bytes calldata callbackData,
        uint256 callbackGasLimit
    ) external virtual returns (uint256 remainingGas, address refundAddress) {}

    /*----------------- external function -----------------*/
    function grant(address, uint32, uint256) external {
        delegateAdditional();
    }

    function revoke(address, uint32) external {
        delegateAdditional();
    }

    function retryPackage() external {
        delegateAdditional();
    }

    /*----------------- update param -----------------*/
    function updateParam(string calldata key, bytes calldata value) external virtual onlyGovHub {
        if (Memory.compareStrings(key, "BaseURI")) {
            IERC721NonTransferable(ERC721Token).setBaseURI(string(value));
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
    ) internal virtual returns (uint256 remainingGas, address refundAddress) {
        (CmnCreateAckPackage memory ackPkg, bool success) = _decodeCmnCreateAckPackage(pkgBytes);
        require(success, "unrecognized create ack package");

        if (ackPkg.status == STATUS_SUCCESS) {
            _doCreate(ackPkg.creator, ackPkg.id);
        } else if (ackPkg.status == STATUS_FAILED) {
            emit CreateFailed(ackPkg.creator, ackPkg.id);
        } else {
            revert("unexpected status code");
        }

        if (ackPkg.extraData.length > 0) {
            ExtraData memory extraData;
            (extraData, success) = _bytesToExtraData(ackPkg.extraData);
            require(success, "unrecognized extra data");

            if (extraData.appAddress != address(0) && callbackGasLimit >= 2300) {
                bytes memory reason;
                bool failed;
                uint256 gasBefore = gasleft();
                try
                    IApplication(extraData.appAddress).handleAckPackage{ gas: callbackGasLimit }(
                        channelId,
                        ackPkg,
                        extraData.callbackData
                    )
                {} catch Error(string memory error) {
                    reason = bytes(error);
                    failed = true;
                } catch (bytes memory lowLevelData) {
                    reason = lowLevelData;
                    failed = true;
                }

                remainingGas = callbackGasLimit > (gasBefore - gasleft())
                    ? callbackGasLimit - (gasBefore - gasleft())
                    : 0;
                refundAddress = extraData.refundAddress;

                if (failed) {
                    bytes32 pkgHash = keccak256(abi.encodePacked(channelId, sequence));
                    emit AppHandleAckPkgFailed(extraData.appAddress, pkgHash, reason);
                    if (extraData.failureHandleStrategy != FailureHandleStrategy.SkipOnFail) {
                        packageMap[pkgHash] = CallbackPackage(
                            extraData.appAddress,
                            CMN_CREATE_ACK,
                            pkgBytes,
                            extraData.callbackData,
                            false,
                            reason
                        );
                        retryQueue[extraData.appAddress].pushBack(pkgHash);
                    }
                }
            }
        }
    }

    function _doCreate(address creator, uint256 id) internal virtual {
        IERC721NonTransferable(ERC721Token).mint(creator, id);
        emit CreateSuccess(creator, id);
    }

    function _handleDeleteAckPackage(
        bytes memory pkgBytes,
        uint64 sequence,
        uint256 callbackGasLimit
    ) internal virtual returns (uint256 remainingGas, address refundAddress) {
        (CmnDeleteAckPackage memory ackPkg, bool success) = _decodeCmnDeleteAckPackage(pkgBytes);
        require(success, "unrecognized delete ack package");

        if (ackPkg.status == STATUS_SUCCESS) {
            _doDelete(ackPkg.id);
        } else if (ackPkg.status == STATUS_FAILED) {
            emit DeleteFailed(ackPkg.id);
        } else {
            revert("unexpected status code");
        }

        if (ackPkg.extraData.length > 0) {
            ExtraData memory extraData;
            (extraData, success) = _bytesToExtraData(ackPkg.extraData);
            require(success, "unrecognized extra data");

            if (extraData.appAddress != address(0) && callbackGasLimit >= 2300) {
                bytes memory reason;
                bool failed;
                uint256 gasBefore = gasleft();
                try
                    IApplication(extraData.appAddress).handleAckPackage{ gas: callbackGasLimit }(
                        channelId,
                        ackPkg,
                        extraData.callbackData
                    )
                {} catch Error(string memory error) {
                    reason = bytes(error);
                    failed = true;
                } catch (bytes memory lowLevelData) {
                    reason = lowLevelData;
                    failed = true;
                }

                remainingGas = callbackGasLimit > (gasBefore - gasleft())
                    ? callbackGasLimit - (gasBefore - gasleft())
                    : 0;
                refundAddress = extraData.refundAddress;

                if (failed) {
                    bytes32 pkgHash = keccak256(abi.encodePacked(channelId, sequence));
                    emit AppHandleAckPkgFailed(extraData.appAddress, pkgHash, reason);
                    if (extraData.failureHandleStrategy != FailureHandleStrategy.SkipOnFail) {
                        packageMap[pkgHash] = CallbackPackage(
                            extraData.appAddress,
                            CMN_DELETE_ACK,
                            pkgBytes,
                            extraData.callbackData,
                            false,
                            reason
                        );
                        retryQueue[extraData.appAddress].pushBack(pkgHash);
                    }
                }
            }
        }
    }

    function _doDelete(uint256 id) internal virtual {
        IERC721NonTransferable(ERC721Token).burn(id);
        emit DeleteSuccess(id);
    }

    function _decodeCmnMirrorSynPackage(
        bytes memory msgBytes
    ) internal pure returns (CmnMirrorSynPackage memory, bool success) {
        CmnMirrorSynPackage memory synPkg;

        RLPDecode.Iterator memory msgIter = msgBytes.toRLPItem().iterator();
        uint8 opType = uint8(msgIter.next().toUint());
        require(opType == TYPE_MIRROR, "wrong syn operation type");

        RLPDecode.Iterator memory pkgIter;
        if (msgIter.hasNext()) {
            pkgIter = msgIter.next().toBytes().toRLPItem().iterator();
        } else {
            revert("wrong syn package");
        }

        uint256 idx;
        while (pkgIter.hasNext()) {
            if (idx == 0) {
                synPkg.id = pkgIter.next().toUint();
            } else if (idx == 1) {
                synPkg.owner = pkgIter.next().toAddress();
                success = true;
            } else {
                break;
            }
            idx++;
        }
        return (synPkg, success);
    }

    function _encodeCmnMirrorAckPackage(CmnMirrorAckPackage memory mirrorAckPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](2);
        elements[0] = uint256(mirrorAckPkg.status).encodeUint();
        elements[1] = mirrorAckPkg.id.encodeUint();
        return _RLPEncode(TYPE_MIRROR, elements.encodeList());
    }

    function _handleMirrorSynPackage(bytes memory msgBytes) internal virtual returns (bytes memory) {
        (CmnMirrorSynPackage memory synPkg, bool success) = _decodeCmnMirrorSynPackage(msgBytes);
        require(success, "unrecognized mirror package");

        uint32 status = _doMirror(synPkg);
        CmnMirrorAckPackage memory mirrorAckPkg = CmnMirrorAckPackage({ status: status, id: synPkg.id });
        return _encodeCmnMirrorAckPackage(mirrorAckPkg);
    }

    function _doMirror(CmnMirrorSynPackage memory synPkg) internal virtual returns (uint32) {
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
    ) internal virtual returns (uint256 remainingGas, address refundAddress) {
        (CmnDeleteSynPackage memory synPkg, bool success) = _decodeCmnDeleteSynPackage(pkgBytes);
        require(success, "unrecognized delete fail ack package");

        if (synPkg.extraData.length > 0) {
            ExtraData memory extraData;
            (extraData, success) = _bytesToExtraData(synPkg.extraData);
            require(success, "unrecognized extra data");

            if (extraData.appAddress != address(0) && callbackGasLimit >= 2300) {
                bytes memory reason;
                bool failed;
                uint256 gasBefore = gasleft();
                try
                    IApplication(extraData.appAddress).handleFailAckPackage{ gas: callbackGasLimit }(
                        channelId,
                        synPkg,
                        extraData.callbackData
                    )
                {} catch Error(string memory error) {
                    reason = bytes(error);
                    failed = true;
                } catch (bytes memory lowLevelData) {
                    reason = lowLevelData;
                    failed = true;
                }

                remainingGas = callbackGasLimit > (gasBefore - gasleft())
                    ? callbackGasLimit - (gasBefore - gasleft())
                    : 0;
                refundAddress = extraData.refundAddress;

                if (failed) {
                    bytes32 pkgHash = keccak256(abi.encodePacked(channelId, sequence));
                    emit AppHandleAckPkgFailed(extraData.appAddress, pkgHash, reason);
                    if (extraData.failureHandleStrategy != FailureHandleStrategy.SkipOnFail) {
                        packageMap[pkgHash] = CallbackPackage(
                            extraData.appAddress,
                            CMN_DELETE_SYN,
                            pkgBytes,
                            extraData.callbackData,
                            true,
                            reason
                        );
                        retryQueue[extraData.appAddress].pushBack(pkgHash);
                    }
                }
            }
        }
    }

    function _bytesToExtraData(
        bytes memory _extraDataBytes
    ) internal pure returns (ExtraData memory _extraData, bool success) {
        RLPDecode.Iterator memory iter = _extraDataBytes.toRLPItem().iterator();

        uint256 idx;
        while (iter.hasNext()) {
            if (idx == 0) {
                _extraData.appAddress = iter.next().toAddress();
            } else if (idx == 1) {
                _extraData.refundAddress = iter.next().toAddress();
            } else if (idx == 2) {
                _extraData.failureHandleStrategy = FailureHandleStrategy(uint8(iter.next().toUint()));
            } else if (idx == 3) {
                _extraData.callbackData = iter.next().toBytes();
                success = true;
            } else {
                break;
            }
            idx++;
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
