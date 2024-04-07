// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../Config.sol";
import "../interface/ICrossChain.sol";
import "../interface/IGreenfieldExecutor.sol";
import "../interface/IMiddleLayer.sol";

contract GreenfieldExecutor is Config, Initializable, IMiddleLayer, IGreenfieldExecutor {
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {}

    /**
     * @notice Send messages to GNFD
     *
     * @param _msgTypes The greenfield message types.
     * Supported message types and its corresponding number
     * 1: CreatePaymentAccount
     * 2: Deposit
     * 3: DisableRefund
     * 4: Withdraw
     * 5: MigrateBucket
     * 6: CancelMigrateBucket
     * 7: UpdateBucketInfo
     * 8: ToggleSPAsDelegatedAgent
     * 9: SetBucketFlowRateLimit
     * 10: CopyObject
     * 11: UpdateObjectInfo
     * 12: UpdateGroupExtra
     * 13: SetTag
     * @param _msgBytes The greenfield message bytes encoded by protobuf.
     * Please refer to https://docs.bnbchain.org/greenfield-docs/docs/guide/core-concept/cross-chain/executor/ for more details.
     */
    function execute(uint8[] calldata _msgTypes, bytes[] calldata _msgBytes) external payable override returns (bool) {
        uint256 _length = _msgTypes.length;
        require(_length > 0, "empty data");
        require(_length == _msgBytes.length, "length not match");

        (uint256 relayFee, ) = ICrossChain(CROSS_CHAIN).getRelayFees();
        require(msg.value == relayFee, "invalid value for relay fee");

        // generate packages
        bytes[] memory messages = new bytes[](_msgBytes.length);
        for (uint256 i = 0; i < _length; ++i) {
            require(_msgTypes[i] != 0, "invalid message type");
            messages[i] = abi.encode(msg.sender, _msgTypes[i], _msgBytes[i]);
        }

        // send sync package
        ICrossChain(CROSS_CHAIN).sendSynPackage(GNFD_EXECUTOR_CHANNEL_ID, abi.encode(messages), msg.value, 0);

        return true;
    }

    function versionInfo()
        external
        pure
        override
        returns (uint256 version, string memory name, string memory description)
    {
        return (1_000_001, "GreenfieldExecutor", "init");
    }

    function handleSynPackage(uint8, bytes calldata) external pure returns (bytes memory responsePayload) {
        revert("receive unexpected syn package");
    }

    function handleAckPackage(
        uint8,
        uint64,
        bytes calldata,
        uint256
    ) external pure returns (uint256 remainingGas, address refundAddress) {
        revert("receive unexpected ack package");
    }

    function handleFailAckPackage(
        uint8,
        uint64,
        bytes calldata,
        uint256
    ) external pure returns (uint256 remainingGas, address refundAddress) {
        revert("receive unexpected fail ack package");
    }
}
