// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/DoubleEndedQueueUpgradeable.sol";

import "./AccessControl.sol";
import "./NFTWrapResourceStorage.sol";
import "../interface/ICrossChain.sol";
import "../interface/IERC721NonTransferable.sol";
import "../lib/RLPDecode.sol";
import "../lib/RLPEncode.sol";

// Highlight: This contract must have the same storage layout as ObjectHub
// which means same state variables and same order of state variables.
// Because it will be used as a delegate call target.
// NOTE: The inherited contracts order must be the same as ObjectHub.
contract AdditionalObjectHub is Initializable, NFTWrapResourceStorage, AccessControl {
    using DoubleEndedQueueUpgradeable for DoubleEndedQueueUpgradeable.Bytes32Deque;
    using RLPEncode for *;
    using RLPDecode for *;

    function grant(address account, uint32 acCode, uint256 expireTime) external {
        if (expireTime == 0) {
            expireTime = block.timestamp + 30 days; // 30 days in default
        }

        if (acCode & AUTH_CODE_DELETE != 0) {
            acCode = acCode & ~AUTH_CODE_DELETE;
            grantRole(ROLE_DELETE, account, expireTime);
        }

        require(acCode == 0, "invalid authorization code");
    }

    function revoke(address account, uint32 acCode) external {
        if (acCode & AUTH_CODE_DELETE != 0) {
            acCode = acCode & ~AUTH_CODE_DELETE;
            revokeRole(ROLE_DELETE, account);
        }

        require(acCode == 0, "invalid authorization code");
    }

    /**
     * @dev delete a object and send cross-chain request from BSC to GNFD
     *
     * @param id The bucket's id
     */
    function deleteObject(uint256 id) external payable returns (bool) {
        // check fee
        require(msg.value >= relayFee + ackRelayFee, "not enough fee");
        uint256 _ackRelayFee = msg.value - relayFee;

        // check authorization
        address owner = IERC721NonTransferable(ERC721Token).ownerOf(id);
        if (
            !(
                msg.sender == owner || IERC721NonTransferable(ERC721Token).getApproved(id) == msg.sender
                    || IERC721NonTransferable(ERC721Token).isApprovedForAll(owner, msg.sender)
            )
        ) {
            require(hasRole(ROLE_DELETE, owner, msg.sender), "no permission to delete");
        }

        // make sure the extra data is as expected
        CmnDeleteSynPackage memory synPkg = CmnDeleteSynPackage({operator: owner, id: id, extraData: ""});

        address _crossChain = CROSS_CHAIN;
        ICrossChain(_crossChain).sendSynPackage(
            OBJECT_CHANNEL_ID, _encodeCmnDeleteSynPackage(synPkg), relayFee, _ackRelayFee
        );
        emit DeleteSubmitted(owner, msg.sender, id, relayFee, _ackRelayFee);
        return true;
    }

    /**
     * @dev delete a object and send cross-chain request from BSC to GNFD
     * Callback function will be called when the request is processed
     *
     * @param id The bucket's id
     * @param extraData The extra data for callback function
     */
    function deleteObject(uint256 id, uint256 callbackGasLimit, ExtraData memory extraData)
        external
        payable
        returns (bool)
    {
        // check relay fee and callback fee
        require(msg.value >= relayFee + ackRelayFee + callbackGasLimit * tx.gasprice, "not enough fee");
        uint256 _ackRelayFee = msg.value - relayFee - callbackGasLimit * tx.gasprice;

        // check package queue
        if (extraData.failureHandleStrategy == FailureHandleStrategy.HandleInSequence) {
            require(
                retryQueue[msg.sender].length() == 0,
                "retry queue is not empty, please process the previous package first"
            );
        }

        // check authorization
        address owner = IERC721NonTransferable(ERC721Token).ownerOf(id);
        if (
            !(
                msg.sender == owner || IERC721NonTransferable(ERC721Token).getApproved(id) == msg.sender
                    || IERC721NonTransferable(ERC721Token).isApprovedForAll(owner, msg.sender)
            )
        ) {
            require(hasRole(ROLE_DELETE, owner, msg.sender), "no permission to delete");
        }

        // make sure the extra data is as expected
        extraData.appAddress = msg.sender;
        CmnDeleteSynPackage memory synPkg =
            CmnDeleteSynPackage({operator: owner, id: id, extraData: _extraDataToBytes(extraData)});

        // check refund address
        (bool success,) = extraData.refundAddress.call{gas: transferGas}("");
        require(success && (extraData.refundAddress != address(0)), "invalid refund address"); // the refund address must be payable

        address _crossChain = CROSS_CHAIN;
        ICrossChain(_crossChain).sendSynPackage(
            OBJECT_CHANNEL_ID, _encodeCmnDeleteSynPackage(synPkg), relayFee, _ackRelayFee
        );
        emit DeleteSubmitted(owner, msg.sender, id, relayFee, _ackRelayFee);
        return true;
    }

    /*----------------- internal function -----------------*/
    function _encodeCmnDeleteSynPackage(CmnDeleteSynPackage memory synPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](2);
        elements[0] = synPkg.operator.encodeAddress();
        elements[1] = synPkg.id.encodeUint();
        return _RLPEncode(TYPE_DELETE, elements.encodeList());
    }
}
