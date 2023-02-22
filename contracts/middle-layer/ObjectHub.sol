// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "./NFTHub.sol";
import "../interface/IERC721NonTransferable.sol";
import "../interface/ICrossChain.sol";

contract ObjectHub is NFTHub {
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

    // TODO: create/delete object
    function handleAckPackage(uint8, bytes calldata) external view override onlyCrossChainContract {
        revert("should not happen");
    }

    function handleFailAckPackage(uint8, bytes calldata) external view override onlyCrossChainContract {
        revert("should not happen");
    }
}
