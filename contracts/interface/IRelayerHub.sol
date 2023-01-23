pragma solidity ^0.8.0;

interface IRelayerHub {
    function isRelayer(address sender) external view returns (bool);
}
