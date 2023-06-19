// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "./CmnEncode.sol";
import "../storage/GroupStorage.sol";

contract GroupEncode is GroupStorage, CmnEncode {
    /*----------------- encode -----------------*/
    function encodeCreateGroupSynPackage(CreateGroupSynPackage calldata synPkg) external pure returns (bytes memory) {
        return wrapEncode(TYPE_CREATE, abi.encode(synPkg));
    }

    function encodeUpdateGroupSynPackage(UpdateGroupSynPackage calldata synPkg) external pure returns (bytes memory) {
        return wrapEncode(TYPE_UPDATE, abi.encode(synPkg));
    }

    /*----------------- decode -----------------*/
    function decodeCreateGroupSynPackage(
        bytes calldata pkgBytes
    ) external pure returns (CreateGroupSynPackage memory synPkg, bool success) {
        return (abi.decode(pkgBytes, (CreateGroupSynPackage)), true);
    }

    function decodeUpdateGroupSynPackage(
        bytes calldata pkgBytes
    ) external pure returns (UpdateGroupSynPackage memory synPkg, bool success) {
        return (abi.decode(pkgBytes, (UpdateGroupSynPackage)), true);
    }

    function decodeUpdateGroupAckPackage(
        bytes calldata pkgBytes
    ) external pure returns (UpdateGroupAckPackage memory, bool) {
        return (abi.decode(pkgBytes, (UpdateGroupAckPackage)), true);
    }
}
