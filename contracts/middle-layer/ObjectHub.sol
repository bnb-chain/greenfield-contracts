// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "./AccessControl.sol";
import "./NFTWrapResourceHub.sol";
import "../interface/ICrossChain.sol";
import "../interface/IERC721NonTransferable.sol";
import "../lib/RLPDecode.sol";
import "../lib/RLPEncode.sol";

contract ObjectHub is NFTWrapResourceHub, AccessControl {
    using RLPEncode for *;
    using RLPDecode for *;

    function initialize(address _ERC721_token, address _additional) public initializer {
        ERC721Token = _ERC721_token;
        additional = _additional;

        relayFee = 2e15;
        ackRelayFee = 2e15;
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

    // TODO: create object
    /**
     * @dev handle ack cross-chain package from GNFD，it means create/delete operation handled by GNFD successfully.
     *
     * @param msgBytes The rlp encoded message bytes sent from GNFD
     */
    function handleAckPackage(uint8, bytes calldata msgBytes) external override onlyCrossChainContract {
        RLPDecode.Iterator memory msgIter = msgBytes.toRLPItem().iterator();

        uint8 opType = uint8(msgIter.next().toUint());
        RLPDecode.Iterator memory pkgIter;
        if (msgIter.hasNext()) {
            pkgIter = msgIter.next().toBytes().toRLPItem().iterator();
        } else {
            revert("wrong ack package");
        }

        if (opType == TYPE_DELETE) {
            _handleDeleteAckPackage(pkgIter);
        } else {
            revert("unexpected operation type");
        }
    }

    function handleFailAckPackage(uint8, bytes calldata) external view override onlyCrossChainContract {
        revert("should not happen");
    }

    /*----------------- external function -----------------*/
    /**
     * @dev delete a Object and send cross-chain request from BSC to GNFD
     *
     * @param id The bucket's id
     */
    function deleteObject(uint256 id) external payable returns (bool) {
        delegateAdditional();
    }
}
