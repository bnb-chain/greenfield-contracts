// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../interface/IERC721.sol";
import "../interface/IERC1155.sol";
import "../Config.sol";
import "../lib/RLPEncode.sol";
import "../lib/RLPDecode.sol";
import "../interface/ICrossChain.sol";

contract CredentialHub is Initializable, Config {
    using RLPEncode for *;
    using RLPDecode for *;

    /*----------------- constants -----------------*/
    // res code
    uint8 public constant MIRROR_SUCCESS = 0;
    uint8 public constant UNKNOWN_RESOURCE_TYPE = 1;

    // status of ack package
    uint32 public constant STATUS_SUCCESS = 0;
    uint32 public constant STATUS_FAILED = 1;

    // mirror type
    uint8 public constant TYPE_BUCKET = 1;
    uint8 public constant TYPE_OBJECT = 2;
    uint8 public constant TYPE_GROUP = 3;

    /*----------------- storage layer -----------------*/
    uint256 public relayFee;
    uint256 public ackRelayFee;

    // credential contracts
    address public bucket;
    address public object;
    address public group;
    address public member;
    address public permission;

    /*----------------- struct / event / modifier -----------------*/
    struct CreateBucketSynPackage {
        address creator;
        string bucketName;
        bool isPublic;
        address paymentAddress;
        address primarySpAddress;
        bytes primarySpSignature;
    }

    struct CreateGroupSynPackage {
        address creator;
        string groupName;
        address[] members;
    }

    // GNFD to BSC
    struct CreateAckPackage {
        uint32 status;
        address creator;
        uint256 id;
    }

    // BSC to GNFD
    struct DeleteSynPackage {
        address operator;
        string name;
    }

    // GNFD to BSC
    struct DeleteAckPackage {
        uint32 status;
        uint256 id;
    }

    // GNFD to BSC
    struct MirrorSynPackage {
        uint256 id;
        bytes key;
        address owner;
    }

    // BSC to GNFD
    struct MirrorAckPackage {
        uint32 status;
        bytes key;
    }

    event MirrorSuccess(uint8 resourceType, uint256 id, address owner);
    event CreateBucketSubmitted(address creator, string bucketName, uint256 relayFee, uint256 ackRelayFee);
    event CreateGroupSubmitted(address creator, string groupName, uint256 relayFee, uint256 ackRelayFee);
    event CreateBucketFailed(address creator, uint256 id);
    event CreateGroupFailed(address creator, uint256 id);
    event CreateBucketSuccessful(address creator, uint256 id);
    event CreateGroupSuccessful(address creator, uint256 id);
    event DeleteBucketSubmitted(address operator, string bucketName, uint256 relayFee, uint256 ackRelayFee);
    event DeleteGroupSubmitted(address operator, string groupName, uint256 relayFee, uint256 ackRelayFee);
    event DeleteBucketFailed(uint256 id);
    event DeleteGroupFailed(uint256 id);
    event DeleteBucketSuccessful(uint256 id);
    event DeleteGroupSuccessful(uint256 id);
    event FailAckPkgReceived(uint8 channelId, bytes msgBytes);
    event UnexpectedPackage(uint8 channelId, bytes msgBytes);
    event ParamChange(string key, bytes value);

    modifier onlyCrossChainContract() {
        require(msg.sender == CROSS_CHAIN, "only CrossChain contract");
        _;
    }

    /*----------------- external function -----------------*/
//    function initialize(address _bucket, address _object, address _group, address _member, address _permission)
//        public
//        initializer
//    {
//        bucket = _bucket;
//        object = _object;
//        group = _group;
//        member = _member;
//        permission = _permission;
//
//        relayFee = 2e15;
//        ackRelayFee = 2e15;
//    }

    function initialize()
        public
        initializer
    {
        relayFee = 2e15;
        ackRelayFee = 2e15;
    }

    receive() external payable {}

    /**
     * @dev handle sync cross-chain package from BSC to GNFD
     *
     * @param channelId The channel for cross-chain communication
     * @param msgBytes The rlp encoded message bytes sent from BSC to GNFD
     */
    function handleSynPackage(uint8 channelId, bytes calldata msgBytes)
        external
        onlyCrossChainContract
        returns (bytes memory)
    {
        if (channelId == MIRROR_BUCKET_CHANNELID) {
            return _handleMirrorSynPackage(TYPE_BUCKET, msgBytes);
        } else if (channelId == MIRROR_OBJECT_CHANNELID) {
            return _handleMirrorSynPackage(TYPE_OBJECT, msgBytes);
        } else if (channelId == MIRROR_GROUP_CHANNELID) {
            return _handleMirrorSynPackage(TYPE_GROUP, msgBytes);
        } else {
            // should not happen
            require(false, "unrecognized syn package");
            return new bytes(0);
        }
    }

    /**
     * @dev handle ack cross-chain package from GNFD，it means create/delete operation successfully to GNFD.
     *
     * @param channelId The channel for cross-chain communication
     * @param msgBytes The rlp encoded message bytes sent from GNFD
     */
    function handleAckPackage(uint8 channelId, bytes calldata msgBytes) external onlyCrossChainContract {
        if (channelId == CREATE_BUCKET_CHANNELID) {
            _handleCreateAckPackage(TYPE_BUCKET, msgBytes);
        } else if (channelId == CREATE_GROUP_CHANNELID) {
            _handleCreateAckPackage(TYPE_GROUP, msgBytes);
        } else if (channelId == DELETE_BUCKET_CHANNELID) {
            _handleDeleteAckPackage(TYPE_BUCKET, msgBytes);
        } else if (channelId == DELETE_GROUP_CHANNELID) {
            _handleDeleteAckPackage(TYPE_GROUP, msgBytes);
        } else {
            emit UnexpectedPackage(channelId, msgBytes);
        }
    }

    /**
     * @dev handle failed ack cross-chain package from GNFD, it means failed to cross-chain syn request to GNFD.
     *
     * @param channelId The channel for cross-chain communication
     * @param msgBytes The rlp encoded message bytes sent from GNFD
     */
    function handleFailAckPackage(uint8 channelId, bytes calldata msgBytes) external onlyCrossChainContract {
        emit FailAckPkgReceived(channelId, msgBytes);
    }

    /**
     * @dev create a bucket and send cross-chain request from BSC to GNFD
     *
     * @param bucketName The bucket's name
     * @param isPublic The bucket is public or not
     * @param paymentAddress The address of the fee payer
     * @param spAddress The primary sp address that store the bucket resource
     * @param spSignature The primary sp's signature
     */
    function createBucket(
        string calldata bucketName,
        bool isPublic,
        address paymentAddress,
        address spAddress,
        bytes calldata spSignature
    ) external payable returns (bool) {
        require(msg.value >= relayFee + ackRelayFee, "received BNB amount should be no less than the minimum relayFee");
        uint256 _ackRelayFee = msg.value - relayFee;

        CreateBucketSynPackage memory synPkg = CreateBucketSynPackage({
            creator: msg.sender,
            bucketName: bucketName,
            isPublic: isPublic,
            paymentAddress: paymentAddress,
            primarySpAddress: spAddress,
            primarySpSignature: spSignature
        });

        address _crossChain = CROSS_CHAIN;
        ICrossChain(_crossChain).sendSynPackage(
            CREATE_BUCKET_CHANNELID, _encodeCreateBucketSynPackage(synPkg), relayFee, _ackRelayFee
        );
        emit CreateBucketSubmitted(msg.sender, bucketName, relayFee, _ackRelayFee);
        return true;
    }

    /**
     * @dev create a group and send cross-chain request from BSC to GNFD
     *
     * @param groupName The group's name
     * @param members The initial members of the group
     */
    function createGroup(string calldata groupName, address[] calldata members) external payable returns (bool) {
        require(msg.value >= relayFee + ackRelayFee, "received BNB amount should be no less than the minimum relayFee");
        uint256 _ackRelayFee = msg.value - relayFee;

        CreateGroupSynPackage memory synPkg =
            CreateGroupSynPackage({creator: msg.sender, groupName: groupName, members: members});

        address _crossChain = CROSS_CHAIN;
        ICrossChain(_crossChain).sendSynPackage(
            CREATE_GROUP_CHANNELID, _encodeCreateGroupSynPackage(synPkg), relayFee, _ackRelayFee
        );
        emit CreateGroupSubmitted(msg.sender, groupName, relayFee, _ackRelayFee);
        return true;
    }

    /**
     * @dev delete a bucket and send cross-chain request from BSC to GNFD
     *
     * @param bucketName The bucket's name
     */
    function deleteBucket(string calldata bucketName) external payable returns (bool) {
        require(msg.value >= relayFee + ackRelayFee, "received BNB amount should be no less than the minimum relayFee");
        uint256 _ackRelayFee = msg.value - relayFee;

        DeleteSynPackage memory synPkg = DeleteSynPackage({operator: msg.sender, name: bucketName});

        address _crossChain = CROSS_CHAIN;
        ICrossChain(_crossChain).sendSynPackage(
            DELETE_BUCKET_CHANNELID, _encodeDeleteSynPackage(synPkg), relayFee, _ackRelayFee
        );
        emit DeleteBucketSubmitted(msg.sender, bucketName, relayFee, _ackRelayFee);
        return true;
    }

    /**
     * @dev delete a group and send cross-chain request from BSC to GNFD
     *
     * @param groupName The group's name
     */
    function deleteGroup(string calldata groupName) external payable returns (bool) {
        require(msg.value >= relayFee + ackRelayFee, "received BNB amount should be no less than the minimum relayFee");
        uint256 _ackRelayFee = msg.value - relayFee;

        DeleteSynPackage memory synPkg = DeleteSynPackage({operator: msg.sender, name: groupName});

        address _crossChain = CROSS_CHAIN;
        ICrossChain(_crossChain).sendSynPackage(
            DELETE_GROUP_CHANNELID, _encodeDeleteSynPackage(synPkg), relayFee, _ackRelayFee
        );
        emit DeleteGroupSubmitted(msg.sender, groupName, relayFee, _ackRelayFee);
        return true;
    }

    /*----------------- internal function -----------------*/
    function _decodeMirrorSynPackage(bytes memory msgBytes) internal pure returns (MirrorSynPackage memory, bool) {
        MirrorSynPackage memory synPkg;

        RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
        bool success = false;
        uint256 idx = 0;
        while (iter.hasNext()) {
            if (idx == 0) {
                synPkg.id = iter.next().toUint();
            } else if (idx == 1) {
                synPkg.key = iter.next().toBytes();
            } else if (idx == 2) {
                synPkg.owner = iter.next().toAddress();
                success = true;
            } else {
                break;
            }
            idx++;
        }
        return (synPkg, success);
    }

    function _encodeMirrorAckPackage(MirrorAckPackage memory mirrorAckPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](2);
        elements[0] = uint256(mirrorAckPkg.status).encodeUint();
        elements[1] = mirrorAckPkg.key.encodeBytes();
        return elements.encodeList();
    }

    function _handleMirrorSynPackage(uint8 resourceType, bytes memory msgBytes) internal returns (bytes memory) {
        (MirrorSynPackage memory synPkg, bool success) = _decodeMirrorSynPackage(msgBytes);
        require(success, "unrecognized mirror package");
        uint32 resCode = _doMirror(resourceType, synPkg);
        MirrorAckPackage memory mirrorAckPkg = MirrorAckPackage({status: resCode, key: synPkg.key});
        return _encodeMirrorAckPackage(mirrorAckPkg);
    }

    function _doMirror(uint8 resourceType, MirrorSynPackage memory synPkg) internal returns (uint32) {
        if (resourceType == TYPE_BUCKET) {
            IERC721(bucket).mint(synPkg.owner, synPkg.id);
        } else if (resourceType == TYPE_OBJECT) {
            IERC721(object).mint(synPkg.owner, synPkg.id);
        } else if (resourceType == TYPE_GROUP) {
            IERC721(group).mint(synPkg.owner, synPkg.id);
        } else {
            return UNKNOWN_RESOURCE_TYPE;
        }
        emit MirrorSuccess(resourceType, synPkg.id, synPkg.owner);
        return MIRROR_SUCCESS;
    }

    function _decodeCreateAckPackage(bytes memory msgBytes) internal pure returns (CreateAckPackage memory, bool) {
        CreateAckPackage memory ackPkg;

        RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
        bool success = false;
        uint256 idx = 0;
        while (iter.hasNext()) {
            if (idx == 0) {
                ackPkg.status = uint32(iter.next().toUint());
            } else if (idx == 1) {
                ackPkg.creator = iter.next().toAddress();
            } else if (idx == 2) {
                ackPkg.id = iter.next().toUint();
                success = true;
            } else {
                break;
            }
            idx++;
        }
        return (ackPkg, success);
    }

    function _handleCreateAckPackage(uint8 resourceType, bytes memory msgBytes) internal {
        (CreateAckPackage memory ackPkg, bool decodeSuccess) = _decodeCreateAckPackage(msgBytes);
        require(decodeSuccess, "unrecognized create ack package");
        if (ackPkg.status == STATUS_SUCCESS) {
            _doCreate(resourceType, ackPkg.creator, ackPkg.id);
        } else if (ackPkg.status == STATUS_FAILED) {
            if (resourceType == TYPE_BUCKET) {
                emit CreateBucketFailed(ackPkg.creator, ackPkg.id);
            } else if (resourceType == TYPE_GROUP) {
                emit CreateGroupFailed(ackPkg.creator, ackPkg.id);
            }
        } else {
            require(false, "unexpected status code");
        }
    }

    function _doCreate(uint8 resourceType, address creator, uint256 id) internal {
        if (resourceType == TYPE_BUCKET) {
            IERC721(bucket).mint(creator, id);
            emit CreateBucketSuccessful(creator, id);
        } else if (resourceType == TYPE_GROUP) {
            IERC721(group).mint(creator, id);
            emit CreateGroupSuccessful(creator, id);
        }
    }

    function _decodeDeleteAckPackage(bytes memory msgBytes) internal pure returns (DeleteAckPackage memory, bool) {
        DeleteAckPackage memory ackPkg;

        RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
        bool success = false;
        uint256 idx = 0;
        while (iter.hasNext()) {
            if (idx == 0) {
                ackPkg.status = uint32(iter.next().toUint());
            } else if (idx == 1) {
                ackPkg.id = iter.next().toUint();
                success = true;
            } else {
                break;
            }
            idx++;
        }
        return (ackPkg, success);
    }

    function _handleDeleteAckPackage(uint8 resourceType, bytes memory msgBytes) internal {
        (DeleteAckPackage memory ackPkg, bool decodeSuccess) = _decodeDeleteAckPackage(msgBytes);
        require(decodeSuccess, "unrecognized delete ack package");
        if (ackPkg.status == STATUS_SUCCESS) {
            _doDelete(resourceType, ackPkg.id);
        } else if (ackPkg.status == STATUS_FAILED) {
            if (resourceType == TYPE_BUCKET) {
                emit DeleteBucketFailed(ackPkg.id);
            } else if (resourceType == TYPE_GROUP) {
                emit DeleteGroupFailed(ackPkg.id);
            }
        } else {
            require(false, "unexpected status code");
        }
    }

    function _doDelete(uint8 resourceType, uint256 id) internal {
        if (resourceType == TYPE_BUCKET) {
            IERC721(bucket).burn(id);
            emit DeleteBucketSuccessful(id);
        } else if (resourceType == TYPE_GROUP) {
            IERC721(group).burn(id);
            emit DeleteGroupSuccessful(id);
        }
    }

    function _encodeCreateBucketSynPackage(CreateBucketSynPackage memory synPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](6);
        elements[0] = synPkg.creator.encodeAddress();
        elements[1] = bytes(synPkg.bucketName).encodeBytes();
        elements[2] = synPkg.isPublic.encodeBool();
        elements[3] = synPkg.paymentAddress.encodeAddress();
        elements[4] = synPkg.primarySpAddress.encodeAddress();
        elements[5] = synPkg.primarySpSignature.encodeBytes();
        return elements.encodeList();
    }

    function _encodeCreateGroupSynPackage(CreateGroupSynPackage memory synPkg) internal pure returns (bytes memory) {
        bytes[] memory members = new bytes[](synPkg.members.length);
        for (uint256 i; i < synPkg.members.length; ++i) {
            members[i] = synPkg.members[i].encodeAddress();
        }

        bytes[] memory elements = new bytes[](3);
        elements[0] = synPkg.creator.encodeAddress();
        elements[1] = bytes(synPkg.groupName).encodeBytes();
        elements[2] = members.encodeList();
        return elements.encodeList();
    }

    function _encodeDeleteSynPackage(DeleteSynPackage memory synPkg) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](2);
        elements[0] = synPkg.operator.encodeAddress();
        elements[1] = bytes(synPkg.name).encodeBytes();
        return elements.encodeList();
    }
}
