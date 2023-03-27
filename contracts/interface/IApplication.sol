// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

interface IApplication {
    /**
     * @param status The status of the cross-chain package.
     * uint32 public constant STATUS_SUCCESS = 0;
     * uint32 public constant STATUS_FAILED = 1;
     * uint32 public constant STATUS_UNEXPECTED = 2;
     * @param channelId The channel ID of the cross-chain package.
     * uint8 public constant BUCKET_CHANNEL_ID = 0x04;
     * uint8 public constant OBJECT_CHANNEL_ID = 0x05;
     * uint8 public constant GROUP_CHANNEL_ID = 0x06;
     * @param operationType The operation type of the cross-chain package.
     * uint8 public constant TYPE_CREATE = 2;
     * uint8 public constant TYPE_DELETE = 3;
     * uint8 public constant TYPE_UPDATE = 4;
     * @param resourceId The ERC721 token ID of the resource that is being operated on.
     * Sometimes, this param is not valid, such as when the status is STATUS_UNEXPECTED.
     * In this case, the resourceId is 0.
     */
    function greenfieldCall(
        uint32 status,
        uint8 channelId,
        uint8 operationType,
        uint256 resourceId,
        bytes calldata callbackData
    ) external;
}
