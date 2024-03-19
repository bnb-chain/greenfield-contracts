// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../Config.sol";
import "../interface/ICrossChain.sol";
import "../interface/IGreenfieldExecutor.sol";

contract GreenfieldExecutor is Config, Initializable, IGreenfieldExecutor {
    // Supported message types and its corresponding number
    // 1: CreatePaymentAccount
    // 2: Deposit
    // 3: DisableRefund
    // 4: UpdateParams
    // 5: Withdraw
    // 6: MigrateBucket
    // 7: CancelMigrateBucket
    // 8: CompleteMigrateBucket
    // 9: RejectMigrateBucket
    // 10: UpdateBucketInfo
    // 11: ToggleSPAsDelegatedAgent
    // 12: DiscontinueBucket
    // 13: SetBucketFlowRateLimit
    // 14: CopyObject
    // 15: DiscontinueObject
    // 16: UpdateObjectInfo
    // 17: LeaveGroup
    // 18: UpdateGroupExtra
    // 19: SetTag
    // 20: CancelUpdateObjectContent

    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {}

    function execute(uint8[] calldata _msgTypes, bytes[] calldata _msgBytes) external payable override returns (bool) {
        uint256 _length = _msgTypes.length;
        require(_length > 0, "empty data");
        require(_length == _msgBytes.length, "length not match");

        (uint256 relayFee, ) = ICrossChain(CROSS_CHAIN).getRelayFees();
        require(msg.value == relayFee, "invalid value for relay fee");

        // generate packages
        bytes[] memory messages = new bytes[](_msgBytes.length);
        for (uint256 i = 0; i < _length; ++i) {
            require(_msgTypes[i] != MsgType.Unspecified, "invalid message type");
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
}
