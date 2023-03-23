// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract GnfdProxy is TransparentUpgradeableProxy {
    constructor(
        address _logic,
        address admin_,
        bytes memory _data
    ) payable TransparentUpgradeableProxy(_logic, admin_, _data) {}
}
