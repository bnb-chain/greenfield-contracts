pragma solidity ^0.8.0;

interface IGovHub {
    function proxyAdmin() external view returns (address);
    function crosschain() external view returns (address);
    function lightClient() external view returns (address);
    function tokenHub() external view returns (address);
    function relayerHub() external view returns (address);
}
