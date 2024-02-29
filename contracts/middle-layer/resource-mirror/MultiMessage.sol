// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../../interface/ICrossChain.sol";
import "../../interface/IMultiMessage.sol";
import "./CmnHub.sol";
import "./storage/MultiStorage.sol";

contract MultiMessage is MultiStorage, CmnHub, IMultiMessage {
    mapping(address => bool) public whitelistTargets;

    constructor() {
        _disableInitializers();
    }

    /*----------------- initializer -----------------*/
    function initialize(address _ERC721_token, address _additional) public initializer {
        __cmn_hub_init_unchained(_ERC721_token, _additional);

        channelId = MULTI_MESSAGE_CHANNEL_ID;

        whitelistTargets[BUCKET_HUB] = true;
        whitelistTargets[GROUP_HUB] = true;
        whitelistTargets[OBJECT_HUB] = true;
        whitelistTargets[PERMISSION_HUB] = true;
        whitelistTargets[TOKEN_HUB] = true;
    }

    function initializeV2() public reinitializer(2) {
        __cmn_hub_init_unchained_v2(INIT_MAX_CALLBACK_DATA_LENGTH);
    }

    function sendMessages(
        address[] calldata _targets,
        bytes[] calldata _data,
        uint256[] calldata _values
    ) external payable returns (bool) {
        require(_targets.length == _data.length, "length mismatch");
        require(_targets.length == _values.length, "length mismatch");

        // generate packages
        uint256 _totalValue = 0;
        uint256 _totalRelayFee = 0;
        uint256 _totalAckRelayFee = 0;
        bytes[] memory messages = new bytes[](_targets.length);
        for (uint256 i = 0; i < _targets.length; ++i) {
            address target = _targets[i];
            require(whitelistTargets[target], "only whitelist");
            uint256 value = _values[i];
            _totalValue += value;
            bytes calldata data = _data[i];

            (bool success, bytes memory result) = target.call{ value: value }(data);
            require(success, "call reverted");

            (, , uint256 _relayFee, uint256 _ackRelayFee, address sender) = abi.decode(result, (uint8, bytes, uint256, uint256, address));
            require(msg.sender == sender, "invalid sender");

            _totalRelayFee += _relayFee;
            _totalAckRelayFee += _ackRelayFee;

            messages[i] = result;
        }
        require(_totalValue == msg.value, "invalid msg.value");
        require(_totalRelayFee + _totalAckRelayFee == msg.value, "invalid total relayFee");

        // send sync package
        ICrossChain(CROSS_CHAIN).sendSynPackage(
            MULTI_MESSAGE_CHANNEL_ID,
            abi.encodePacked(TYPE_MULTI_MESSAGE, abi.encode(messages)),
            _totalRelayFee,
            _totalAckRelayFee
        );

        return true;
    }

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

    function versionInfo()
        external
        pure
        override
        returns (uint256 version, string memory name, string memory description)
    {
        return (900_001, "MultiMessage", "init");
    }
}
