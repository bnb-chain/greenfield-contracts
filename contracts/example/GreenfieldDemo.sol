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

    enum Status{NotStart,Pending, Successed,Failed}

    event CreateBucket(string bucketName ,uint32 status);
    event CreatePolicy(bytes32 executorDataHash,uint32 status);

    function createBucket(
        string memory bucketName,
        uint256 transferOutAmount,
        bytes memory _executorData,
        uint256 _callbackGasLimit,
        uint8 _failureHandleStrategy
    ) external payable {
        (uint256 relayFee,uint256 ackRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        uint256 gasPrice = ICrossChain(CROSS_CHAIN).callbackGasPrice();

        require(msg.value >= _callbackGasLimit * gasPrice + transferOutAmount + relayFee * 3 + ackRelayFee * 2, "msg.value not enough");

        // 1. transferOut to address(this) on greenfield
        ITokenHub(TOKEN_HUB).transferOut{ value: transferOutAmount + relayFee + ackRelayFee }(
            address(this),
            transferOutAmount
        );

        // 2. set bucket flow rate limit
        uint8[] memory _msgTypes = new uint8[](1);
        _msgTypes[0] = 9; // * 9: SetBucketFlowRateLimit
        bytes[] memory _msgBytes = new bytes[](1);
        _msgBytes[0] = _executorData;
        IGreenfieldExecutor(GREENFIELD_EXECUTOR).execute{ value: relayFee }(_msgTypes, _msgBytes);

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

        bytes memory _callbackData = bytes(bucketName);

        CmnStorage.ExtraData memory _extraData = CmnStorage.ExtraData({
            appAddress: address(this),
            refundAddress: msg.sender,
            failureHandleStrategy: PackageQueue.FailureHandleStrategy(_failureHandleStrategy),
            callbackData: _callbackData
        });

        IBucketHub(BUCKET_HUB).createBucket{value:_callbackGasLimit * gasPrice + relayFee + ackRelayFee }(createPackage,_callbackGasLimit,_extraData);
    }

    function createPolicy(
        bytes memory createPolicyData, 
        uint256 _callbackGasLimit,
        uint8 _failureHandleStrategy) external payable {
        
        bytes32 dataHash = keccak256(createPolicyData);
        bytes memory _callbackData = abi.encode(dataHash);
        CmnStorage.ExtraData memory _extraData = CmnStorage.ExtraData({
                appAddress: address(this),
                refundAddress: msg.sender,
                failureHandleStrategy: PackageQueue.FailureHandleStrategy(_failureHandleStrategy),
                callbackData: _callbackData
        });
        uint256 value = _getTotelFee(_callbackGasLimit);
        require(msg.value >= value,"msg.value not enough");

        IPermissionHub(PERMISSION_HUB).createPolicy{ value: msg.value }(createPolicyData,_extraData); 
    }

    // @bnb-chain/greenfield-contracts/contracts/Config.sol
    int8 public constant TRANSFER_IN_CHANNEL_ID = 0x01;
    uint8 public constant TRANSFER_OUT_CHANNEL_ID = 0x02;
    uint8 public constant GOV_CHANNEL_ID = 0x03;
    uint8 public constant BUCKET_CHANNEL_ID = 0x04;
    uint8 public constant OBJECT_CHANNEL_ID = 0x05;
    uint8 public constant GROUP_CHANNEL_ID = 0x06;
    uint8 public constant PERMISSION_CHANNEL_ID = 0x07;
    uint8 public constant MULTI_MESSAGE_CHANNEL_ID = 0x08;
    uint8 public constant GNFD_EXECUTOR_CHANNEL_ID = 0x09;

    //  @bnb-chain/greenfield-contracts/contracts/middle-layer/resource-mirror/storage/CmnStorage.sol
    uint32 public constant STATUS_SUCCESS = 0;
    uint32 public constant STATUS_FAILED = 1;
    uint32 public constant STATUS_UNEXPECTED = 2;

    // operation type
    uint8 public constant TYPE_MIRROR = 1;
    uint8 public constant TYPE_CREATE = 2;
    uint8 public constant TYPE_DELETE = 3;
    uint8 public constant TYPE_MULTI_MESSAGE = 4;
    function greenfieldCall(
        uint32 status,
        uint8 resourceType,
        uint8 operationType,
        uint256 resourceId,
        bytes calldata callbackData
    ) external {
        require(msg.sender == BUCKET_HUB || msg.sender == PERMISSION_HUB, "Invalid caller");
        if (resourceType == RESOURCE_BUCKET) {
            _bucketGreenfieldCall(status, callbackData);
        } else if (resourceType == PERMISSION_CHANNEL) {
            _policyGreenfieldCall(status, callbackData);
        } else {
            revert("Invalid Resource");
        }
    }

    function _bucketGreenfieldCall(uint32 status,bytes calldata callbackData) internal { 
        (string memory bucketName) = abi.decode(callbackData,(string));
        //state = 0: success
        //      = 1: failed
        emit CreateBucket(bucketName,status);
    }

     function _policyGreenfieldCall(
        uint32 status,
        bytes calldata callbackData) internal {
        bytes32 executorDataHash = abi.decode(callbackData,(bytes32));
        emit CreatePolicy(executorDataHash, status);
    }


    function _getTotelFee(uint256 _callbackGasLimit) internal returns (uint256) {
        (uint256 relayFee, uint256 minAckRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        uint256 gasPrice = ICrossChain(CROSS_CHAIN).callbackGasPrice();
        return relayFee + minAckRelayFee + _callbackGasLimit * gasPrice;
    }
}
