// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/structs/DoubleEndedQueueUpgradeable.sol";

import "./AccessControl.sol";
import "./NFTWrapResourceHub.sol";
import "../interface/ICrossChain.sol";
import "../interface/IERC1155NonTransferable.sol";
import "../interface/IERC721NonTransferable.sol";
import "../lib/RLPDecode.sol";
import "../lib/RLPEncode.sol";

contract GroupHub is NFTWrapResourceHub, AccessControl {
    using DoubleEndedQueueUpgradeable for DoubleEndedQueueUpgradeable.Bytes32Deque;
    using RLPEncode for *;
    using RLPDecode for *;

    /*----------------- constants -----------------*/
    // operation type
    uint8 public constant TYPE_UPDATE = 4;

    // update type
    uint8 public constant UPDATE_ADD = 1;
    uint8 public constant UPDATE_DELETE = 2;

    // authorization code
    uint32 public constant AUTH_CODE_UPDATE = 4; // 0100

    // role
    bytes32 public constant ROLE_UPDATE = keccak256("ROLE_UPDATE");

    // package type
    bytes32 public constant CREATE_GROUP_SYN = keccak256("CREATE_GROUP_SYN");
    bytes32 public constant UPDATE_GROUP_SYN = keccak256("UPDATE_GROUP_SYN");
    bytes32 public constant UPDATE_GROUP_ACK = keccak256("UPDATE_GROUP_ACK");

    // ERC1155 token contract
    address public ERC1155Token;

    function initialize(address _ERC721_token, address _ERC1155_token, address _additional) public initializer {
        ERC721Token = _ERC721_token;
        ERC1155Token = _ERC1155_token;
        additional = _additional;

        channelId = GROUP_CHANNEL_ID;
    }

    /*----------------- middle-layer app function -----------------*/

    /**
     * @dev handle sync cross-chain package from BSC to GNFD
     *
     * @param msgBytes The rlp encoded message bytes sent from BSC to GNFD
     */
    function handleSynPackage(uint8, bytes calldata msgBytes) external override onlyCrossChain returns (bytes memory) {
        return _handleMirrorSynPackage(msgBytes);
    }

    /**
     * @dev handle ack cross-chain package from GNFD，it means create/delete/update operation handled by GNFD successfully.
     *
     * @param sequence The sequence of the ack package
     * @param msgBytes The rlp encoded message bytes sent from GNFD
     * @param callbackGasLimit The gas limit for callback
     */
    function handleAckPackage(
        uint8,
        uint64 sequence,
        bytes calldata msgBytes,
        uint256 callbackGasLimit
    ) external override onlyCrossChain returns (uint256 remainingGas, address refundAddress) {
        RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();

        uint8 opType = uint8(iter.next().toUint());
        bytes memory pkgBytes;
        if (iter.hasNext()) {
            pkgBytes = iter.next().toBytes();
        } else {
            revert("wrong ack package");
        }

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
     * @param msgBytes The rlp encoded message bytes sent from GNFD
     * @param callbackGasLimit The gas limit for callback
     */
    function handleFailAckPackage(
        uint8 channelId,
        uint64 sequence,
        bytes calldata msgBytes,
        uint256 callbackGasLimit
    ) external override onlyCrossChain returns (uint256 remainingGas, address refundAddress) {
        RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();

        uint8 opType = uint8(iter.next().toUint());
        bytes memory pkgBytes;
        if (iter.hasNext()) {
            pkgBytes = iter.next().toBytes();
        } else {
            revert("wrong failAck package");
        }

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
        return (600_001, "GroupHub", "init version");
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
    function updateParam(string calldata key, bytes calldata value) external override onlyGovHub {
        if (Memory.compareStrings(key, "ERC721BaseURI")) {
            IERC721NonTransferable(ERC721Token).setBaseURI(string(value));
        } else if (Memory.compareStrings(key, "ERC1155BaseURI")) {
            IERC1155NonTransferable(ERC1155Token).setBaseURI(string(value));
        } else {
            revert("unknown param");
        }
        emit ParamChange(key, value);
    }

    /*----------------- internal function -----------------*/
    function _decodeUpdateGroupAckPackage(
        bytes memory pkgBytes
    ) internal pure returns (UpdateGroupAckPackage memory, bool) {
        UpdateGroupAckPackage memory ackPkg;
        RLPDecode.Iterator memory iter = pkgBytes.toRLPItem().iterator();

        bool success;
        uint256 idx;
        while (iter.hasNext()) {
            if (idx == 0) {
                ackPkg.status = uint32(iter.next().toUint());
            } else if (idx == 1) {
                ackPkg.id = iter.next().toUint();
            } else if (idx == 2) {
                ackPkg.operator = iter.next().toAddress();
            } else if (idx == 3) {
                ackPkg.opType = uint8(iter.next().toUint());
            } else if (idx == 4) {
                RLPDecode.RLPItem[] memory membersIter = iter.next().toList();
                address[] memory members = new address[](membersIter.length);
                for (uint256 i; i < membersIter.length; ++i) {
                    members[i] = membersIter[i].toAddress();
                }
                ackPkg.members = members;
            } else if (idx == 5) {
                ackPkg.extraData = iter.next().toBytes();
                success = true;
            } else {
                break;
            }
            idx++;
        }
        return (ackPkg, success);
    }

    function _handleUpdateGroupAckPackage(bytes memory pkgBytes, uint64 sequence, uint256 callbackGasLimit)
        internal
        returns (uint256 remainingGas, address refundAddress)
    {
        (UpdateGroupAckPackage memory ackPkg, bool success) = _decodeUpdateGroupAckPackage(pkgBytes);
        require(success, "unrecognized update ack package");

        if (ackPkg.status == STATUS_SUCCESS) {
            _doUpdate(ackPkg);
        } else if (ackPkg.status == STATUS_FAILED) {
            emit UpdateFailed(ackPkg.operator, ackPkg.id, ackPkg.opType);
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
                try IApplication(extraData.appAddress).handleAckPackage{gas: callbackGasLimit}(
                    channelId, ackPkg, extraData.callbackData
                ) {} catch Error(string memory error) {
                    reason = bytes(error);
                    failed = true;
                } catch (bytes memory lowLevelData) {
                    reason = lowLevelData;
                    failed = true;
                }

                remainingGas =
                    callbackGasLimit > (gasBefore - gasleft()) ? callbackGasLimit - (gasBefore - gasleft()) : 0;
                refundAddress = extraData.refundAddress;

                if (failed) {
                    bytes32 pkgHash = keccak256(abi.encodePacked(channelId, sequence));
                    emit AppHandleAckPkgFailed(extraData.appAddress, pkgHash, reason);
                    if (extraData.failureHandleStrategy != FailureHandleStrategy.SkipOnFail) {
                        packageMap[pkgHash] = CallbackPackage(
                            extraData.appAddress, UPDATE_GROUP_ACK, pkgBytes, extraData.callbackData, true, reason
                        );
                        retryQueue[extraData.appAddress].pushBack(pkgHash);
                    }
                }
            }
        }
    }

    function _doUpdate(UpdateGroupAckPackage memory ackPkg) internal {
        if (ackPkg.opType == UPDATE_ADD) {
            for (uint256 i; i < ackPkg.members.length; ++i) {
                IERC1155NonTransferable(ERC1155Token).mint(ackPkg.members[i], ackPkg.id, 1, "");
            }
        } else if (ackPkg.opType == UPDATE_DELETE) {
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
        emit UpdateSuccess(ackPkg.operator, ackPkg.id, ackPkg.opType);
    }

    function _decodeCreateGroupSynPackage(
        bytes memory pkgBytes
    ) internal pure returns (CreateGroupSynPackage memory synPkg, bool success) {
        RLPDecode.Iterator memory iter = pkgBytes.toRLPItem().iterator();

        uint256 idx;
        while (iter.hasNext()) {
            if (idx == 0) {
                synPkg.creator = iter.next().toAddress();
            } else if (idx == 1) {
                synPkg.name = string(iter.next().toBytes());
            } else if (idx == 2) {
                synPkg.extraData = iter.next().toBytes();
                success = true;
            } else {
                break;
            }
            idx++;
        }
        return (synPkg, success);
    }

    function _handleCreateFailAckPackage(bytes memory pkgBytes, uint64 sequence, uint256 callbackGasLimit)
        internal
        returns (uint256 remainingGas, address refundAddress)
    {
        (CreateGroupSynPackage memory synPkg, bool success) = _decodeCreateGroupSynPackage(pkgBytes);
        require(success, "unrecognized create group fail ack package");

        if (synPkg.extraData.length > 0) {
            ExtraData memory extraData;
            (extraData, success) = _bytesToExtraData(synPkg.extraData);
            require(success, "unrecognized extra data");

            if (extraData.appAddress != address(0) && callbackGasLimit >= 2300) {
                bytes memory reason;
                bool failed;
                uint256 gasBefore = gasleft();
                try IApplication(extraData.appAddress).handleFailAckPackage{gas: callbackGasLimit}(
                    channelId, synPkg, extraData.callbackData
                ) {} catch Error(string memory error) {
                    reason = bytes(error);
                    failed = true;
                } catch (bytes memory lowLevelData) {
                    reason = lowLevelData;
                    failed = true;
                }

                remainingGas =
                    callbackGasLimit > (gasBefore - gasleft()) ? callbackGasLimit - (gasBefore - gasleft()) : 0;
                refundAddress = extraData.refundAddress;

                if (failed) {
                    bytes32 pkgHash = keccak256(abi.encodePacked(channelId, sequence));
                    emit AppHandleAckPkgFailed(extraData.appAddress, pkgHash, reason);
                    if (extraData.failureHandleStrategy != FailureHandleStrategy.SkipOnFail) {
                        packageMap[pkgHash] = CallbackPackage(
                            extraData.appAddress, CREATE_GROUP_SYN, pkgBytes, extraData.callbackData, true, reason
                        );
                        retryQueue[extraData.appAddress].pushBack(pkgHash);
                    }
                }
            }
        }
    }

    function _decodeUpdateGroupSynPackage(bytes memory pkgBytes)
        internal
        pure
        returns (UpdateGroupSynPackage memory synPkg, bool success)
    {
        RLPDecode.Iterator memory iter = pkgBytes.toRLPItem().iterator();

        uint256 idx;
        while (iter.hasNext()) {
            if (idx == 0) {
                synPkg.operator = iter.next().toAddress();
            } else if (idx == 1) {
                synPkg.id = iter.next().toUint();
            } else if (idx == 2) {
                synPkg.opType = uint8(iter.next().toUint());
            } else if (idx == 3) {
                RLPDecode.RLPItem[] memory membersIter = iter.next().toList();
                address[] memory members = new address[](membersIter.length);
                for (uint256 i; i < membersIter.length; ++i) {
                    members[i] = membersIter[i].toAddress();
                }
                synPkg.members = members;
            } else if (idx == 4) {
                synPkg.extraData = iter.next().toBytes();
                success = true;
            } else {
                break;
            }
            idx++;
        }
        return (synPkg, success);
    }

    function _handleUpdateFailAckPackage(bytes memory pkgBytes, uint64 sequence, uint256 callbackGasLimit)
        internal
        returns (uint256 remainingGas, address refundAddress)
    {
        (UpdateGroupSynPackage memory synPkg, bool success) = _decodeUpdateGroupSynPackage(pkgBytes);
        require(success, "unrecognized create group fail ack package");

        if (synPkg.extraData.length > 0) {
            ExtraData memory extraData;
            (extraData, success) = _bytesToExtraData(synPkg.extraData);
            require(success, "unrecognized extra data");

            if (extraData.appAddress != address(0) && callbackGasLimit >= 2300) {
                bytes memory reason;
                bool failed;
                uint256 gasBefore = gasleft();
                try IApplication(extraData.appAddress).handleFailAckPackage{gas: callbackGasLimit}(
                    channelId, synPkg, extraData.callbackData
                ) {} catch Error(string memory error) {
                    reason = bytes(error);
                    failed = true;
                } catch (bytes memory lowLevelData) {
                    reason = lowLevelData;
                    failed = true;
                }

                remainingGas =
                    callbackGasLimit > (gasBefore - gasleft()) ? callbackGasLimit - (gasBefore - gasleft()) : 0;
                refundAddress = extraData.refundAddress;

                if (failed) {
                    bytes32 pkgHash = keccak256(abi.encodePacked(channelId, sequence));
                    emit AppHandleAckPkgFailed(extraData.appAddress, pkgHash, reason);
                    if (extraData.failureHandleStrategy != FailureHandleStrategy.SkipOnFail) {
                        packageMap[pkgHash] = CallbackPackage(
                            extraData.appAddress, UPDATE_GROUP_SYN, pkgBytes, extraData.callbackData, true, reason
                        );
                        retryQueue[extraData.appAddress].pushBack(pkgHash);
                    }
                }
            }
        }
    }
}
