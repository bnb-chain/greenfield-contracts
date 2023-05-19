// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "./IAccessControl.sol";
import "./IMiddleLayer.sol";

interface ICmnHub is IAccessControl, IMiddleLayer {
    function grant(address account, uint32 authCode, uint256 expireTime) external;

    function revoke(address account, uint32 authCode) external;

    function retryPackage() external;

    function skipPackage() external;
}
