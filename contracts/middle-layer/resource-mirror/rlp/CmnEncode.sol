// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "../storage/CmnStorage.sol";

contract CmnEncode is CmnStorage {
    /*----------------- encode -----------------*/
    function encodeCmnMirrorAckPackage(CmnMirrorAckPackage calldata mirrorAckPkg) external pure returns (bytes memory) {
        return wrapEncode(TYPE_MIRROR, abi.encode(mirrorAckPkg));
    }

    function encodeCmnDeleteSynPackage(CmnDeleteSynPackage calldata synPkg) external pure returns (bytes memory) {
        return wrapEncode(TYPE_DELETE, abi.encode(synPkg));
    }

    function encodeExtraData(ExtraData calldata _extraData) external pure returns (bytes memory) {
        return abi.encode(_extraData);
    }

    function wrapEncode(uint8 opType, bytes memory msgBytes) public pure returns (bytes memory) {
        return abi.encode(opType, msgBytes);
    }

    /*----------------- decode -----------------*/
    function decodeCmnMirrorSynPackage(
        bytes calldata msgBytes
    ) external pure returns (CmnMirrorSynPackage memory, bool success) {
        (uint8 opType, CmnMirrorSynPackage memory synPkg) = abi.decode(msgBytes, (uint8, CmnMirrorSynPackage));
        require(opType == TYPE_MIRROR, "wrong syn operation type");
        return (synPkg, true);
    }

    function decodeCmnCreateAckPackage(
        bytes calldata pkgBytes
    ) external pure returns (CmnCreateAckPackage memory, bool) {
        CmnCreateAckPackage memory ackPkg = abi.decode(pkgBytes, (CmnCreateAckPackage));
        return (ackPkg, true);
    }

    function decodeCmnDeleteSynPackage(
        bytes calldata pkgBytes
    ) external pure returns (CmnDeleteSynPackage memory, bool success) {
        CmnDeleteSynPackage memory synPkg = abi.decode(pkgBytes, (CmnDeleteSynPackage));
        return (synPkg, true);
    }

    function decodeCmnDeleteAckPackage(
        bytes calldata pkgBytes
    ) external pure returns (CmnDeleteAckPackage memory, bool success) {
        CmnDeleteAckPackage memory ackPkg = abi.decode(pkgBytes, (CmnDeleteAckPackage));
        return (ackPkg, true);
    }

    function decodeExtraData(
        bytes calldata _extraDataBytes
    ) external pure returns (ExtraData memory _extraData, bool success) {
        (_extraData) = abi.decode(_extraDataBytes, (ExtraData));
        success = true;
    }
}
