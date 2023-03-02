pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    /**
     * @dev Emitted when `account` is granted `role` from `granter`.
     *
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed granter, uint256 expireTime);

    /**
     * @dev Emitted when `account` is revoked `role` from `granter`.
     *
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed granter);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address granter, address account) external view returns (bool);

    /**
     * @dev Grants `role` to `account` with `expireTime`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s granter.
     */
    function grantRole(bytes32 role, address account, uint256 expireTime) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s granter.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account` that has `role` from granter.
     */
    function renounceRole(bytes32 role, address granter) external;
}
