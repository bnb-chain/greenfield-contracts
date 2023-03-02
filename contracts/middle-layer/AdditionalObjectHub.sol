// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./AccessControl.sol";
import "./NFTWrapResourceStorage.sol";

contract AdditionalObjectHub is Initializable, NFTWrapResourceStorage, AccessControl {
    function grant(address account, uint32 acCode, uint256 expireTime) external {
        if (expireTime == 0) {
            expireTime = block.timestamp + 30 days; // 30 days in default
        }

        if (acCode & AUTH_CODE_MIRROR != 0) {
            acCode = acCode & ~AUTH_CODE_MIRROR;
            grantRole(ROLE_MIRROR, account, expireTime);
        }
        if (acCode & AUTH_CODE_CREATE != 0) {
            acCode = acCode & ~AUTH_CODE_CREATE;
            grantRole(ROLE_CREATE, account, expireTime);
        }
        if (acCode & AUTH_CODE_DELETE != 0) {
            acCode = acCode & ~AUTH_CODE_DELETE;
            grantRole(ROLE_DELETE, account, expireTime);
        }
    }

    function revoke(address account, uint32 acCode) external {
        if (acCode & AUTH_CODE_MIRROR != 0) {
            acCode = acCode & ~AUTH_CODE_MIRROR;
            revokeRole(ROLE_MIRROR, account);
        }
        if (acCode & AUTH_CODE_CREATE != 0) {
            acCode = acCode & ~AUTH_CODE_CREATE;
            revokeRole(ROLE_CREATE, account);
        }
        if (acCode & AUTH_CODE_DELETE != 0) {
            acCode = acCode & ~AUTH_CODE_DELETE;
            revokeRole(ROLE_DELETE, account);
        }
    }
}
