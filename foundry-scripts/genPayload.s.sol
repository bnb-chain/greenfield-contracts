pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../contracts/GnfdProxy.sol";
import "../contracts/GnfdProxyAdmin.sol";
import "../contracts/GnfdLightClient.sol";
import "../contracts/CrossChain.sol";
import "../contracts/middle-layer/GovHub.sol";
import "../contracts/middle-layer/TokenHub.sol";

contract genPayloadScript is Script {
    uint32 public constant gnfdChainId = 1;
    uint32 public constant SYN_PACKAGE = 0;

    function run() public {}

    function genPayload() public pure returns (bytes memory) {
        uint16 srcChainid = 1;
        uint16 dstChainid = 2;
        uint8 channelId = 2;
        uint64 sequence = 1778;
        uint8 packageType = 0;
        uint64 time = 1673564596;
        uint256 relayFee = 1e18;
        uint256 ackRelayFee = 5e17;

        bytes memory packageLoad = hex"1234567890";

        bytes memory payload = abi.encodePacked(
            srcChainid, dstChainid, channelId, sequence, packageType, time, relayFee, ackRelayFee, packageLoad
        );
        return payload;
    }

    function decodePayload(bytes calldata payload) public view {
        _checkPayload(payload);
    }

    function _checkPayload(bytes calldata payload)
        internal
        view
        returns (
            bool success,
            uint8 channelId,
            uint64 sequence,
            uint8 packageType,
            uint64 time,
            uint256 relayFee,
            uint256 ackRelayFee, // optional
            bytes memory packageLoad
        )
    {
        bytes memory _payload = payload;

        if (_payload.length < 54) {
            return (false, 0, 0, 0, 0, 0, 0, "");
        }

        uint256 ptr;
        {
            uint16 srcChainId;
            uint16 dstChainId;
            assembly {
                ptr := _payload

                srcChainId := mload(add(ptr, 2))
                dstChainId := mload(add(ptr, 4))
            }

            console.log("srcChainId", srcChainId);
            console.log("dstChainId", dstChainId);
        }

        assembly {
            channelId := mload(add(ptr, 5))
            sequence := mload(add(ptr, 13))
            packageType := mload(add(ptr, 14))
            time := mload(add(ptr, 22))
            relayFee := mload(add(ptr, 54))
        }

        if (packageType == SYN_PACKAGE) {
            if (payload.length < 54 + 32) {
                return (false, 0, 0, 0, 0, 0, 0, "");
            }

            assembly {
                ackRelayFee := mload(add(ptr, 86))
            }
            packageLoad = payload[54 + 32:];
        } else {
            ackRelayFee = 0;
            packageLoad = payload[54:];
        }

        console.log("channelId", channelId);
        console.log("sequence", sequence);
        console.log("packageType", packageType);
        console.log("time", time);
        console.log("relayFee", relayFee);
        console.log("ackRelayFee", ackRelayFee);
        console.log("packageLoad", iToHex(packageLoad));
    }

    function iToHex(bytes memory buffer) public pure returns (string memory) {
        // Fixed buffer size for hexadecimal convertion
        bytes memory converted = new bytes(buffer.length * 2);
        bytes memory _base = "0123456789abcdef";
        for (uint256 i = 0; i < buffer.length; i++) {
            converted[i * 2] = _base[uint8(buffer[i]) / _base.length];
            converted[i * 2 + 1] = _base[uint8(buffer[i]) % _base.length];
        }
        return string(abi.encodePacked("0x", converted));
    }
}
