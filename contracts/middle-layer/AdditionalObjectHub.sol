// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./NFTWrapResourceStorage.sol";
import "../AccessControl.sol";

contract AdditionalObjectHub is Initializable, NFTWrapResourceStorage, AccessControl {

    function grant(address account, uint32 acCode, uint256 expireTime) external {
        if (expireTime == 0) {
            expireTime = block.timestamp + 30 days; // 30 days in default
        }

        if (acCode & AUTH_CODE_MIRROR != 0) {
            grantRole(ROLE_MIRROR, account, expireTime);
        } else if (acCode & AUTH_CODE_CREATE != 0) {
            grantRole(ROLE_CREATE, account, expireTime);
        } else if (acCode & AUTH_CODE_DELETE != 0) {
            grantRole(ROLE_DELETE, account, expireTime);
        } else {
            revert("unknown authorization code");
        }
    }

    function revoke(address account, uint32 acCode) external {
        if (acCode & AUTH_CODE_MIRROR != 0) {
            revokeRole(ROLE_MIRROR, account);
        } else if (acCode & AUTH_CODE_CREATE != 0) {
            revokeRole(ROLE_CREATE, account);
        } else if (acCode & AUTH_CODE_DELETE != 0) {
            revokeRole(ROLE_DELETE, account);
        } else {
            revert("unknown authorization code");
        }
    }
}
