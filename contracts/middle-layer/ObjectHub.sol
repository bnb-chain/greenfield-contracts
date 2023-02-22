// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "./NFTHub.sol";
import "../interface/IERC721NonTransferable.sol";
import "../interface/ICrossChain.sol";

contract ObjectHub is NFTHub {
    /*----------------- app function -----------------*/

    // TODO: handleSynPackage for create/delete object

    function handleAckPackage(uint8, bytes calldata) external view override onlyCrossChainContract {
        revert("should not happen");
    }

    function handleFailAckPackage(uint8, bytes calldata) external view override onlyCrossChainContract {
        revert("should not happen");
    }
}
