// SPDX-License-Identifier: Apache-2.0.

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

    // ERC1155 token contract
    address public ERC1155Token;

    /*----------------- struct / event -----------------*/
    // BSC to GNFD
    struct CreateSynPackage {
        address creator;
        string name;
        bytes extraData; // rlp encode of ExtraData
    }

    struct UpdateSynPackage {
        address operator;
        uint256 id; // group id
        uint8 opType; // add/remove members
        address[] members;
        bytes extraData; // rlp encode of ExtraData
    }

    // GNFD to BSC
    struct UpdateAckPackage {
        uint32 status;
        address operator;
        uint256 id; // group id
        uint8 opType; // add/remove members
        address[] members;
        bytes extraData; // rlp encode of ExtraData
    }

    event UpdateSubmitted(
        address owner,
        address operator,
        uint256 id,
        uint8 opType,
        address[] members,
        uint256 relayFee,
        uint256 ackRelayFee
    );
    event UpdateSuccess(address operator, uint256 id, uint8 opType);
    event UpdateFailed(address operator, uint256 id, uint8 opType);

    function initialize(address _ERC721_token, address _ERC1155_token, address _additional) public initializer {
        ERC721Token = _ERC721_token;
        ERC1155Token = _ERC1155_token;
        additional = _additional;

        relayFee = 2e15;
        ackRelayFee = 2e15;
        callbackGasPrice = 1e9;
        transferGas = 2300;

        channelId = GROUP_CHANNEL_ID;
    }

    /*----------------- middle-layer app function -----------------*/

    /**
     * @dev handle sync cross-chain package from BSC to GNFD
     *
     * @param msgBytes The rlp encoded message bytes sent from BSC to GNFD
     */
    function handleSynPackage(uint8, bytes calldata msgBytes)
        external
        override
        onlyCrossChainContract
        returns (bytes memory)
    {
        return _handleMirrorSynPackage(msgBytes);
    }

    /**
     * @dev handle ack cross-chain package from GNFD，it means create/delete/update operation handled by GNFD successfully.
     *
     * @param sequence The sequence of the ack package
     * @param msgBytes The rlp encoded message bytes sent from GNFD
     */
    function handleAckPackage(uint8, uint64 sequence, bytes calldata msgBytes)
        external
        override
        onlyCrossChainContract
    {
        RLPDecode.Iterator memory msgIter = msgBytes.toRLPItem().iterator();

        uint8 opType = uint8(msgIter.next().toUint());
        RLPDecode.Iterator memory pkgIter;
        if (msgIter.hasNext()) {
            pkgIter = msgIter.next().toBytes().toRLPItem().iterator();
        } else {
            revert("wrong ack package");
        }

        ExtraData memory extraData;
        if (opType == TYPE_CREATE) {
            extraData = _handleCreateAckPackage(pkgIter);
        } else if (opType == TYPE_DELETE) {
            extraData = _handleDeleteAckPackage(pkgIter);
        } else if (opType == TYPE_UPDATE) {
            extraData = _handleUpdateAckPackage(pkgIter);
        } else {
            revert("unexpected operation type");
        }

        uint256 refundFee = CALLBACK_GAS_LIMIT * callbackGasPrice;
        if (extraData.failureHandleStrategy != FailureHandleStrategy.NoCallBack) {
            uint256 gasBefore = gasleft();
            bytes32 pkgHash = keccak256(abi.encodePacked(channelId, sequence));
            try IApplication(extraData.appAddress).handleAckPackage{gas: CALLBACK_GAS_LIMIT}(
                channelId, msgBytes, extraData.callbackData
            ) {} catch (bytes memory reason) {
                if (extraData.failureHandleStrategy != FailureHandleStrategy.Skip) {
                    packageMap[pkgHash] = RetryPackage(extraData.appAddress, msgBytes, extraData.callbackData, false, reason);
                    retryQueue[extraData.appAddress].pushBack(pkgHash);
                }
            }

            uint256 gasUsed = gasleft() - gasBefore;
            refundFee = (CALLBACK_GAS_LIMIT - gasUsed) * callbackGasPrice;
        }

        // refund
        (bool success,) = extraData.refundAddress.call{gas: transferGas, value: refundFee}("");
        require(success, "refund failed");
    }

    /**
     * @dev handle failed ack cross-chain package from GNFD, it means failed to cross-chain syn request to GNFD.
     *
     * @param sequence The sequence of the fail ack package
     * @param msgBytes The rlp encoded message bytes sent from GNFD
     */
    function handleFailAckPackage(uint8 channelId, uint64 sequence, bytes calldata msgBytes)
        external
        override
        onlyCrossChainContract
    {
        (ExtraData memory extraData, bool success) = _decodeFailAckPackage(msgBytes);
        require(success, "decode fail ack package failed");

        uint256 refundFee = CALLBACK_GAS_LIMIT * callbackGasPrice;
        if (extraData.failureHandleStrategy != FailureHandleStrategy.NoCallBack) {
            uint256 gasBefore = gasleft();
            bytes32 pkgHash = keccak256(abi.encodePacked(channelId, sequence));
            try IApplication(extraData.appAddress).handleAckPackage{gas: CALLBACK_GAS_LIMIT}(
                channelId, msgBytes, extraData.callbackData
            ) {} catch (bytes memory reason) {
                if (extraData.failureHandleStrategy != FailureHandleStrategy.Skip) {
                    packageMap[pkgHash] = RetryPackage(extraData.appAddress, msgBytes, extraData.callbackData, true, reason);
                    retryQueue[extraData.appAddress].pushBack(pkgHash);
                }
            }

            uint256 gasUsed = gasleft() - gasBefore;
            refundFee = (CALLBACK_GAS_LIMIT - gasUsed) * callbackGasPrice;
        }

        // refund
        (success,) = extraData.refundAddress.call{gas: transferGas, value: refundFee}("");
        require(success, "refund failed");

        emit FailAckPkgReceived(channelId, msgBytes);
    }

    /*----------------- external function -----------------*/
    /**
     * @dev create a group and send cross-chain request from BSC to GNFD
     *
     * @param owner The group's owner
     * @param name The group's name
     */
    function createGroup(address owner, string memory name) external payable returns (bool) {
        delegateAdditional();
    }

    /**
     * @dev delete a group and send cross-chain request from BSC to GNFD
     *
     * @param id The group's id
     */
    function deleteGroup(uint256 id) external payable returns (bool) {
        delegateAdditional();
    }

    /**
     * @dev update a group's member and send cross-chain request from BSC to GNFD
     *
     * @param synPkg Package containing information of the group to be updated
     */
    function updateGroup(UpdateSynPackage memory synPkg) external payable returns (bool) {
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
    function _decodeUpdateAckPackage(RLPDecode.Iterator memory iter)
        internal
        pure
        returns (UpdateAckPackage memory, bool)
    {
        UpdateAckPackage memory ackPkg;

        bool success;
        uint256 idx;
        while (iter.hasNext()) {
            if (idx == 0) {
                ackPkg.status = uint32(iter.next().toUint());
            } else if (idx == 1) {
                ackPkg.operator = iter.next().toAddress();
            } else if (idx == 2) {
                ackPkg.id = iter.next().toUint();
            } else if (idx == 3) {
                ackPkg.opType = uint8(iter.next().toUint());
            } else if (idx == 4) {
                RLPDecode.RLPItem[] memory memsIter = iter.next().toList();
                address[] memory mems = new address[](memsIter.length);
                for (uint256 i; i < memsIter.length; ++i) {
                    mems[i] = memsIter[i].toAddress();
                }
                ackPkg.members = mems;
                success = true;
            } else {
                break;
            }
            idx++;
        }
        return (ackPkg, success);
    }

    function _handleUpdateAckPackage(RLPDecode.Iterator memory iter) internal returns (ExtraData memory _extraData) {
        (UpdateAckPackage memory ackPkg, bool success) = _decodeUpdateAckPackage(iter);
        require(success, "unrecognized update ack package");

        if (ackPkg.status == STATUS_SUCCESS) {
            _doUpdate(ackPkg);
        } else if (ackPkg.status == STATUS_FAILED) {
            emit UpdateFailed(ackPkg.operator, ackPkg.id, ackPkg.opType);
        } else {
            revert("unexpected status code");
        }

        (_extraData, success) = _bytesToExtraData(ackPkg.extraData);
        require(success, "unrecognized extra data");
    }

    function _doUpdate(UpdateAckPackage memory ackPkg) internal {
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

    function _decodeFailAckPackage(bytes memory msgBytes)
        internal
        pure
        returns (ExtraData memory extraData, bool success)
    {
        RLPDecode.Iterator memory msgIter = msgBytes.toRLPItem().iterator();

        uint8 opType = uint8(msgIter.next().toUint());
        RLPDecode.Iterator memory pkgIter;
        if (msgIter.hasNext()) {
            pkgIter = msgIter.next().toBytes().toRLPItem().iterator();
        } else {
            return (extraData, false);
        }

        uint256 elementsNum;
        if (opType == TYPE_CREATE) {
            elementsNum = 3;
        } else if (opType == TYPE_DELETE) {
            elementsNum = 3;
        } else if (opType == TYPE_UPDATE) {
            elementsNum = 5;
        } else {
            return (extraData, false);
        }

        for (uint256 i = 0; i < elementsNum - 1; i++) {
            if (pkgIter.hasNext()) {
                pkgIter.next();
            } else {
                return (extraData, false);
            }
        }

        if (pkgIter.hasNext()) {
            (extraData, success) = _bytesToExtraData(pkgIter.next().toBytes());
        }
    }
}
