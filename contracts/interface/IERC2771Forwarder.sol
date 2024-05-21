// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IERC2771Forwarder {
    struct ForwardRequestData {
        address from;
        address to;
        uint256 value;
        uint256 gas;
        uint48 deadline;
        bytes data;
        bytes signature;
    }

    function execute(ForwardRequestData calldata request) external payable;

    function verify(ForwardRequestData calldata request) external view returns (bool);

    function executeBatch(
        ForwardRequestData[] calldata requests,
        address payable refundReceiver
    ) external payable;

    function eip712Domain()
    external
    view
    returns (
        bytes1 fields,
        string memory name,
        string memory version,
        uint256 chainId,
        address verifyingContract,
        bytes32 salt,
        uint256[] memory extensions
    );
}
