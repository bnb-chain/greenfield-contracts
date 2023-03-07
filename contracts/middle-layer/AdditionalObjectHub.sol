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
     * @param refundAddress The address to receive the refund of the gas fee
     * @param callBackData The data to be sent back to the application
     */
    function deleteObject(uint256 id, address refundAddress, bytes memory callBackData)
        external
        payable
        returns (bool)
    {
        address _appAddress = msg.sender;
        FailureHandleStrategy failStrategy = failureHandleMap[_appAddress];
        require(failStrategy != FailureHandleStrategy.Closed, "application closed");

        require(msg.value >= relayFee + ackRelayFee + callBackGasPrice * CALLBACK_GAS_LIMIT, "not enough relay fee");
        uint256 _ackRelayFee = msg.value - relayFee - callBackGasPrice * CALLBACK_GAS_LIMIT;

        // check package queue
        if (failStrategy == FailureHandleStrategy.HandleInOrder) {
            require(
                retryQueue[_appAddress].length() == 0,
                "retry queue is not empty, please process the previous package first"
            );
        }

        // check refund address
        (bool success,) = refundAddress.call{gas: transferGas}("");
        require(success && (refundAddress != address(0)), "invalid refund address"); // the refund address must be payable

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

        CmnDeleteSynPackage memory synPkg = CmnDeleteSynPackage({operator: owner, id: id, extraData: ""});
        ExtraData memory extraData = ExtraData({
            appAddress: _appAddress,
            refundAddress: refundAddress,
            failureHandleStrategy: failStrategy,
            callBackData: callBackData
        });
        synPkg.extraData = _extraDataToBytes(extraData);

        address _crossChain = CROSS_CHAIN;
        ICrossChain(_crossChain).sendSynPackage(
            OBJECT_CHANNEL_ID, _encodeCmnDeleteSynPackage(synPkg), relayFee, _ackRelayFee
        );
        emit DeleteSubmitted(owner, msg.sender, id, relayFee, _ackRelayFee);
        return true;
    }

    function _encodeCmnDeleteSynPackage(CmnDeleteSynPackage memory synPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](2);
        elements[0] = synPkg.operator.encodeAddress();
        elements[1] = synPkg.id.encodeUint();
        return _RLPEncode(TYPE_DELETE, elements.encodeList());
    }
}
