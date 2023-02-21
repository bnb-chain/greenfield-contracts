// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "../interface/IERC721NonTransferable.sol";
import "../interface/ICrossChain.sol";
import "../StorageHub.sol";

contract ObjectHub is StorageHub {
    // TODO: create/delete object

    /*----------------- app function -----------------*/

    /**
    * @dev handle sync cross-chain package from BSC to GNFD
     *
     * @param msgBytes The rlp encoded message bytes sent from BSC to GNFD
     */
    function handleSynPackage(uint8, bytes calldata msgBytes) external onlyCrossChainContract returns (bytes memory) {
        return _handleMirrorSynPackage(msgBytes);
    }

    function handleAckPackage(uint8, bytes calldata) external view onlyCrossChainContract {
        revert("should not happen");
    }

    function handleFailAckPackage(uint8, bytes calldata) external view onlyCrossChainContract {
        revert("should not happen");
    }
}
