// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "./CmnEncode.sol";
import "../storage/BucketStorage.sol";

contract BucketEncode is BucketStorage, CmnEncode {
    /*----------------- encode -----------------*/
    function encodeCreateBucketSynPackage(CreateBucketSynPackage calldata synPkg) external pure returns (bytes memory) {
        return wrapEncode(TYPE_CREATE, abi.encode(synPkg));
    }

    /*----------------- decode -----------------*/
    function decodeCreateBucketSynPackage(
        bytes calldata pkgBytes
    ) external pure returns (CreateBucketSynPackage memory synPkg, bool success) {
        synPkg = (abi.decode(pkgBytes, (CreateBucketSynPackage)));
        return (synPkg, true);
    }
}
