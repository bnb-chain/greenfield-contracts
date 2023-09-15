// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/structs/DoubleEndedQueueUpgradeable.sol";

import "./CmnHub.sol";
import "./utils/GnfdAccessControl.sol";
import "../../interface/IERC1155NonTransferable.sol";
import "../../interface/IERC721NonTransferable.sol";
import "../../interface/IGroupHub.sol";
import "../../lib/BytesToTypes.sol";

contract GroupHub is GroupStorage, GnfdAccessControl, CmnHub, IGroupHub {
    using DoubleEndedQueueUpgradeable for DoubleEndedQueueUpgradeable.Bytes32Deque;

    constructor() {
        _disableInitializers();
    }

    /*----------------- initializer -----------------*/
    function initialize(address _ERC721_token, address _ERC1155_token, address _additional) public initializer {
        __cmn_hub_init_unchained(_ERC721_token, _additional);

        ERC1155Token = _ERC1155_token;
        channelId = GROUP_CHANNEL_ID;
    }

    function initializeV2() public reinitializer(2) {
        __cmn_hub_init_unchained_v2(INIT_MAX_CALLBACK_DATA_LENGTH);
    }

    /*----------------- middle-layer app function -----------------*/
    /**
     * @dev handle sync cross-chain package from BSC to GNFD
     *
     * @param msgBytes The encoded message bytes sent from BSC to GNFD
     */
    function handleSynPackage(uint8, bytes calldata msgBytes) external override onlyCrossChain returns (bytes memory) {
        return _handleMirrorSynPackage(msgBytes);
    }

    /**
     * @dev handle ack cross-chain package from GNFD，it means create/delete/update operation handled by GNFD successfully.
     *
     * @param sequence The sequence of the ack package
     * @param msgBytes The encoded message bytes sent from GNFD
     * @param callbackGasLimit The gas limit for callback
     */
    function handleAckPackage(
        uint8,
        uint64 sequence,
        bytes calldata msgBytes,
        uint256 callbackGasLimit
    ) external override onlyCrossChain returns (uint256 remainingGas, address refundAddress) {
        uint8 opType = uint8(msgBytes[0]);
        bytes memory pkgBytes = msgBytes[1:];

        if (opType == TYPE_CREATE) {
            (remainingGas, refundAddress) = _handleCreateAckPackage(pkgBytes, sequence, callbackGasLimit);
        } else if (opType == TYPE_DELETE) {
            (remainingGas, refundAddress) = _handleDeleteAckPackage(pkgBytes, sequence, callbackGasLimit);
        } else if (opType == TYPE_UPDATE) {
            (remainingGas, refundAddress) = _handleUpdateGroupAckPackage(pkgBytes, sequence, callbackGasLimit);
        } else {
            revert("unexpected operation type");
        }
    }

    /**
     * @dev handle failed ack cross-chain package from GNFD, it means failed to cross-chain syn request to GNFD.
     *
     * @param sequence The sequence of the fail ack package
     * @param msgBytes The encoded message bytes sent from GNFD
     * @param callbackGasLimit The gas limit for callback
     */
    function handleFailAckPackage(
        uint8 channelId,
        uint64 sequence,
        bytes calldata msgBytes,
        uint256 callbackGasLimit
    ) external override onlyCrossChain returns (uint256 remainingGas, address refundAddress) {
        uint8 opType = uint8(msgBytes[0]);
        bytes memory pkgBytes = msgBytes[1:];

        if (opType == TYPE_CREATE) {
            (remainingGas, refundAddress) = _handleCreateFailAckPackage(pkgBytes, sequence, callbackGasLimit);
        } else if (opType == TYPE_DELETE) {
            (remainingGas, refundAddress) = _handleDeleteFailAckPackage(pkgBytes, sequence, callbackGasLimit);
        } else if (opType == TYPE_UPDATE) {
            (remainingGas, refundAddress) = _handleUpdateFailAckPackage(pkgBytes, sequence, callbackGasLimit);
        } else {
            revert("unexpected operation type");
        }

        emit FailAckPkgReceived(channelId, msgBytes);
    }

    /*----------------- external function -----------------*/
    function versionInfo()
        external
        pure
        override
        returns (uint256 version, string memory name, string memory description)
    {
        return (600_003, "GroupHub", "add _disableInitializers in constructor");
    }

    function grant(address, uint32, uint256) external override {
        delegateAdditional();
    }

    function revoke(address, uint32) external override {
        delegateAdditional();
    }

    function createGroup(address, string memory) external payable returns (bool) {
        delegateAdditional();
    }

    function createGroup(address, string memory, uint256, ExtraData memory) external payable returns (bool) {
        delegateAdditional();
    }

    function deleteGroup(uint256) external payable returns (bool) {
        delegateAdditional();
    }

    function deleteGroup(uint256, uint256, ExtraData memory) external payable returns (bool) {
        delegateAdditional();
    }

    function updateGroup(UpdateGroupSynPackage memory) external payable returns (bool) {
        delegateAdditional();
    }

    function updateGroup(UpdateGroupSynPackage memory, uint256, ExtraData memory) external payable returns (bool) {
        delegateAdditional();
    }

    /*----------------- update param -----------------*/
    function updateParam(string calldata key, bytes calldata value) external override onlyGov {
        if (_compareStrings(key, "ERC721BaseURI")) {
            IERC721NonTransferable(ERC721Token).setBaseURI(string(value));
        } else if (_compareStrings(key, "ERC1155BaseURI")) {
            IERC1155NonTransferable(ERC1155Token).setBaseURI(string(value));
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
    function _handleUpdateGroupAckPackage(
        bytes memory pkgBytes,
        uint64 sequence,
        uint256 callbackGasLimit
    ) internal returns (uint256 remainingGas, address refundAddress) {
        UpdateGroupAckPackage memory ackPkg = abi.decode(pkgBytes, (UpdateGroupAckPackage));

        if (ackPkg.status == STATUS_SUCCESS) {
            _doUpdate(ackPkg);
        } else if (ackPkg.status == STATUS_FAILED) {
            emit UpdateFailed(ackPkg.operator, ackPkg.id, uint8(ackPkg.opType));
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
                        TYPE_UPDATE,
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
                            TYPE_UPDATE,
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

    function _doUpdate(UpdateGroupAckPackage memory ackPkg) internal {
        if (ackPkg.opType == UpdateGroupOpType.AddMembers) {
            for (uint256 i; i < ackPkg.members.length; ++i) {
                IERC1155NonTransferable(ERC1155Token).mint(ackPkg.members[i], ackPkg.id, 1, "");
            }
        } else if (ackPkg.opType == UpdateGroupOpType.RemoveMembers) {
            for (uint256 i; i < ackPkg.members.length; ++i) {
                // skip if the member has no token
                if (IERC1155NonTransferable(ERC1155Token).balanceOf(ackPkg.members[i], ackPkg.id) == 0) {
                    continue;
                }
                IERC1155NonTransferable(ERC1155Token).burn(ackPkg.members[i], ackPkg.id, 1);
            }
        } else {
            revert("unexpected update operation");
        }
        emit UpdateSuccess(ackPkg.operator, ackPkg.id, uint8(ackPkg.opType));
    }

    function _handleCreateFailAckPackage(
        bytes memory pkgBytes,
        uint64 sequence,
        uint256 callbackGasLimit
    ) internal returns (uint256 remainingGas, address refundAddress) {
        CreateGroupSynPackage memory synPkg = abi.decode(pkgBytes, (CreateGroupSynPackage));

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
                        TYPE_CREATE,
                        0,
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
                            TYPE_CREATE,
                            0,
                            extraData.callbackData,
                            ""
                        );
                        retryQueue[extraData.appAddress].pushBack(pkgHash);
                    }
                }
            }
        }
    }

    function _handleUpdateFailAckPackage(
        bytes memory pkgBytes,
        uint64 sequence,
        uint256 callbackGasLimit
    ) internal returns (uint256 remainingGas, address refundAddress) {
        UpdateGroupSynPackage memory synPkg = abi.decode(pkgBytes, (UpdateGroupSynPackage));

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
                        TYPE_UPDATE,
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
                            TYPE_UPDATE,
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
}
