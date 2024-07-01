// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "../interface/IBucketHub.sol";
import "../interface/ITokenHub.sol";
import "../interface/ICrossChain.sol";
import "../interface/IPermissionHub.sol";
import "../interface/IGreenfieldExecutor.sol";

contract GreenfieldDemo {
    // testnet
    address public constant TOKEN_HUB = 0xED8e5C546F84442219A5a987EE1D820698528E04;
    address public constant CROSS_CHAIN = 0xa5B2c9194131A4E0BFaCbF9E5D6722c873159cb7;
    address public constant BUCKET_HUB = 0x5BB17A87D03620b313C39C24029C94cB5714814A;
    address public constant PERMISSION_HUB = 0x25E1eeDb5CaBf288210B132321FBB2d90b4174ad;
    address public constant SP_ADDRESS_TESTNET = 0x5FFf5A6c94b182fB965B40C7B9F30199b969eD2f;
    address public constant GREENFIELD_EXECUTOR = 0x3E3180883308e8B4946C9a485F8d91F8b15dC48e;

    function createBucket(string memory bucketName, uint256 transferOutAmount, bytes memory _executorData) external payable {
        (uint256 relayFee, uint256 ackRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        require(msg.value == transferOutAmount + relayFee * 3 + ackRelayFee * 2, "msg.value not enough");

        // 1. transferOut to address(this) on greenfield
        ITokenHub(TOKEN_HUB).transferOut{value: transferOutAmount + relayFee + ackRelayFee}(address(this), transferOutAmount);

        // 2. set bucket flow rate limit
        uint8[] memory _msgTypes = new uint8[](1);
        _msgTypes[0] = 9;  // * 9: SetBucketFlowRateLimit
        bytes[] memory _msgBytes = new bytes[](1);
        _msgBytes[0] = _executorData;
        IGreenfieldExecutor(GREENFIELD_EXECUTOR).execute{value: relayFee}(_msgTypes, _msgBytes);

        // 3. create bucket, owner = address(this)
        BucketStorage.CreateBucketSynPackage memory createPackage = BucketStorage.CreateBucketSynPackage({
            creator: address(this),
            name: bucketName,
            visibility: BucketStorage.BucketVisibilityType.Private,
            paymentAddress: address(this),
            primarySpAddress: SP_ADDRESS_TESTNET,
            primarySpApprovalExpiredHeight: 0,
            globalVirtualGroupFamilyId: 1,
            primarySpSignature: new bytes(0),
            chargedReadQuota: 10485760000,
            extraData: new bytes(0)
        });
        IBucketHub(BUCKET_HUB).createBucket{ value: relayFee + ackRelayFee }(createPackage);
    }

    function createPolicy(bytes memory createPolicyData) external payable {
        IPermissionHub(PERMISSION_HUB).createPolicy{ value: msg.value }(createPolicyData);
    }
}
