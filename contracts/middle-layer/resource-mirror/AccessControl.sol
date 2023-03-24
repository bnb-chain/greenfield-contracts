// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import "../../interface/IAccessControl.sol";

contract AccessControl is Context, IAccessControl, ERC165 {
    // Role => Granter => Operator => ExpireTime
    mapping(bytes32 => mapping(address => mapping(address => uint256))) private _roles;

    /**
     * @dev Modifier that checks that an account has a specific grant. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing grant
     * from (0x[0-9a-f]{40}) as role (0x[0-9a-f]{64})$/
     */
    modifier onlyRole(bytes32 role, address granter) {
        _checkRole(role, granter);
        _;
    }

    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role` from `granter`.
     */
    function hasRole(bytes32 role, address granter, address account) public view virtual returns (bool) {
        return _roles[role][granter][account] > block.timestamp;
    }

    /**
     * @dev Grants `role` to `grantee` from msg.sender.
     *
     * If `grantee` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address grantee, uint256 expireTime) public virtual {
        require(expireTime > block.timestamp, "AccessControl: Expire time must be greater than current time");
        _grantRole(role, _msgSender(), grantee, expireTime);
    }

    /**
     * @dev Revokes `role` from `account` from msg.sender.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual override {
        _revokeRole(role, _msgSender(), account);
    }

    function renounceRole(bytes32 role, address granter) public virtual override {
        _revokeRole(role, granter, _msgSender());
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address granter, address account, uint256 expireTime) internal virtual {
        _roles[role][granter][account] = expireTime;
        emit RoleGranted(role, account, granter, expireTime);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address granter, address account) internal virtual {
        if (hasRole(role, granter, account)) {
            _roles[role][granter][account] = 0;
            emit RoleRevoked(role, account, granter);
        }
    }

    /**
     * @dev Revert with a standard message if `_msgSender()` is missing `role`.
     *
     * Format of the revert message is described in {_checkRole}.
     */
    function _checkRole(bytes32 role, address granter) internal view virtual {
        _checkRole(role, granter, _msgSender());
    }

    /**
     * @dev Revert with a standard message if `operator` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing grant
     * from (0x[0-9a-f]{40}) as role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address granter, address operator) internal view virtual {
        if (!hasRole(role, granter, operator)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        Strings.toHexString(operator),
                        " is missing grant from ",
                        Strings.toHexString(granter),
                        " as role ",
                        Strings.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }
}
