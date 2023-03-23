// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

interface IProxyAdmin {
    function upgrade(address proxy, address implementation) external;

    function getProxyImplementation(address proxy) external view returns (address);
}
