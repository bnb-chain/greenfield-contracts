// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "../Config.sol";
import "../interface/ICrossChain.sol";
import "../interface/IBucketHub.sol";
import "../interface/IGroupHub.sol";
import "../middle-layer/resource-mirror/storage/GroupStorage.sol";
import "../middle-layer/resource-mirror/storage/BucketStorage.sol";

contract MultiMessageSdk is Config {
    function addTransferOut(
        address _sender,
        address[] memory _targets,
        bytes[] memory _data,
        uint256[] memory _values,
        address _receiver,
        uint256 _amount
    ) external view returns (address[] memory targets_, bytes[] memory data_, uint256[] memory values_) {
        (targets_, data_, values_) = _init(_targets, _data, _values);
        uint256 len = _targets.length;

        targets_[len] = address(TOKEN_HUB);
        data_[len] = abi.encodeWithSignature(
            "prepareTransferOut(address,address,uint256)",
            _sender,
            _receiver,
            _amount
        );
        (uint256 relayFee, uint256 minAckRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        values_[len] = _amount + relayFee + minAckRelayFee;
    }

    function addCreateGroup(
        address _sender,
        address[] memory _targets,
        bytes[] memory _data,
        uint256[] memory _values,
        address _owner,
        string memory _name
    ) external view returns (address[] memory targets_, bytes[] memory data_, uint256[] memory values_) {
        (targets_, data_, values_) = _init(_targets, _data, _values);
        uint256 len = _targets.length;

        targets_[len] = address(GROUP_HUB);
        data_[len] = abi.encodeWithSignature("prepareCreateGroup(address,address,string)", _sender, _owner, _name);
        (uint256 relayFee, uint256 minAckRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        values_[len] = relayFee + minAckRelayFee;
    }

    function addGroupMember(
        address _sender,
        address[] memory _targets,
        bytes[] memory _data,
        uint256[] memory _values,
        uint256 _groupId,
        address[] memory _members,
        uint64[] memory _memberExpiration,
        bytes memory extraData
    ) external view returns (address[] memory targets_, bytes[] memory data_, uint256[] memory values_) {
        (targets_, data_, values_) = _init(_targets, _data, _values);
        uint256 len = _targets.length;

        targets_[len] = address(GROUP_HUB);
        GroupStorage.UpdateGroupSynPackage memory synPkg = GroupStorage.UpdateGroupSynPackage({
            operator: _sender,
            id: _groupId,
            opType: GroupStorage.UpdateGroupOpType.AddMembers,
            members: _members,
            extraData: extraData, // abi.encode of ExtraData
            memberExpiration: _memberExpiration // timestamp(UNIX) of member expiration
        });
        data_[len] = abi.encodeCall(IGroupHub.prepareUpdateGroup, (_sender, synPkg));

        (uint256 relayFee, uint256 minAckRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        values_[len] = relayFee + minAckRelayFee;
    }

    function addCreatePolicy(
        address _sender,
        address[] memory _targets,
        bytes[] memory _data,
        uint256[] memory _values,
        bytes memory _policyData
    ) external view returns (address[] memory targets_, bytes[] memory data_, uint256[] memory values_) {
        (targets_, data_, values_) = _init(_targets, _data, _values);
        uint256 len = _targets.length;

        targets_[len] = address(PERMISSION_HUB);
        data_[len] = abi.encodeWithSignature("prepareCreatePolicy(address,bytes)", _sender, _policyData);
        (uint256 relayFee, uint256 minAckRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        values_[len] = relayFee + minAckRelayFee;
    }

    function addCreateBucket(
        address _sender,
        address[] memory _targets,
        bytes[] memory _data,
        uint256[] memory _values,
        BucketStorage.CreateBucketSynPackage memory _synPkg
    ) external view returns (address[] memory targets_, bytes[] memory data_, uint256[] memory values_) {
        (targets_, data_, values_) = _init(_targets, _data, _values);
        uint256 len = _targets.length;

        targets_[len] = address(BUCKET_HUB);
        data_[len] = abi.encodeCall(IBucketHub.prepareCreateBucket, (_sender, _synPkg));
        (uint256 relayFee, uint256 minAckRelayFee) = ICrossChain(CROSS_CHAIN).getRelayFees();
        values_[len] = relayFee + minAckRelayFee;
    }

    function _init(
        address[] memory _targets,
        bytes[] memory _data,
        uint256[] memory _values
    ) internal view returns (address[] memory targets_, bytes[] memory data_, uint256[] memory values_) {
        uint256 len = _targets.length;

        targets_ = new address[](len + 1);
        data_ = new bytes[](len + 1);
        values_ = new uint256[](len + 1);

        for (uint256 i = 0; i < len; i++) {
            targets_[i] = _targets[i];
            data_[i] = _data[i];
            values_[i] = _values[i];
        }
    }
}
