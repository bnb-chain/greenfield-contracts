// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../../interface/IPermissionHub.sol";
import "../../interface/ICrossChain.sol";
import "./CmnHub.sol";

contract PermissionHub is PermissionStorage, CmnHub, IPermissionHub {
    constructor() {
        _disableInitializers();
    }

    /*----------------- initializer -----------------*/
    function initialize(address _ERC721_token, address _additional) public initializer {
        __cmn_hub_init_unchained(_ERC721_token, _additional);

        channelId = PERMISSION_CHANNEL_ID;
    }

    function initializeV2() public reinitializer(2) {
        __cmn_hub_init_unchained_v2(INIT_MAX_CALLBACK_DATA_LENGTH);
    }

    /*----------------- middle-layer app function -----------------*/
    /**
     * @dev handle ack cross-chain package from GNFD，it means create/delete operation handled by GNFD successfully.
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
        } else {
            revert("unexpected operation type");
        }

        emit FailAckPkgReceived(channelId, msgBytes);
    }

    /*----------------- external function -----------------*/
    function createPolicy(bytes calldata) external payable returns (bool) {
        delegateAdditional();
    }

    function createPolicy(bytes calldata, ExtraData memory) external payable returns (bool) {
        delegateAdditional();
    }

    function deletePolicy(uint256) external payable returns (bool) {
        delegateAdditional();
    }

    function deletePolicy(uint256, ExtraData memory) external payable returns (bool) {
        delegateAdditional();
    }

    function prepareCreatePolicy(
        address,
        bytes calldata
    ) external payable returns (uint8, bytes memory, uint256, uint256, address) {
        delegateAdditional();
    }

    function prepareCreatePolicy(
        address,
        bytes calldata,
        ExtraData memory
    ) external payable returns (uint8, bytes memory, uint256, uint256, address) {
        delegateAdditional();
    }

    function prepareDeletePolicy(
        address,
        uint256
    ) external payable returns (uint8, bytes memory, uint256, uint256, address) {
        delegateAdditional();
    }

    function prepareDeletePolicy(
        address,
        uint256,
        ExtraData memory
    ) external payable returns (uint8, bytes memory, uint256, uint256, address) {
        delegateAdditional();
    }

    /*----------------- internal function -----------------*/
    function _handleCreateFailAckPackage(
        bytes memory pkgBytes,
        uint64,
        uint256 callbackGasLimit
    ) internal returns (uint256 remainingGas, address refundAddress) {
        createPolicySynPackage memory synPkg = abi.decode(pkgBytes, (createPolicySynPackage));

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
            }
        }
    }

    function versionInfo()
        external
        pure
        override
        returns (uint256 version, string memory name, string memory description)
    {
        return (800_003, "PermissionHub", "support ERC2771Forwarder");
    }
}
