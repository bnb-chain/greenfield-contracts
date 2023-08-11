// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "contracts/Deployer.sol";
import "contracts/CrossChain.sol";
import "contracts/middle-layer/GovHub.sol";
import "contracts/middle-layer/TokenHub.sol";
import "./TestDeployer.sol";
import "./Helper.sol";

contract CrossChainTest is Helper {
    address private developer = 0x0000000000000000000000000000000012345678;
    address private user1 = 0x1000000000000000000000000000000012345678;
    event TransferOutSuccess(address senderAddress, uint256 amount, uint256 relayFee, uint256 ackRelayFee);

    function setUp() public {
        vm.deal(developer, 10000 ether);
    }

    function test_transferOut() public {
        vm.startPrank(developer);
        address receipt = user1;
        uint256 amount = 1 ether;
        vm.expectEmit(true, true, true, true, address(tokenHub));
        emit TransferOutSuccess(developer, 1 ether, 25 * 1e13, 130 * 1e13);
        tokenHub.transferOut{ value: amount + 155 * 1e13 }(receipt, amount);
        vm.stopPrank();
    }

    function test_decode() public view {
        bytes
            memory _payload = hex"eb0a94fa1a93d8fe3834d33a6e79f795859367ca1229669450e3f659803ffdf09813bdef9be4a14ad85f31f8";
        this._checkPayload(_payload);
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

    /*
    1. sync package of GNFD -> BSC
    | SrcChainId | DestChainId | ChannelId | Sequence | PackageType | Timestamp | RelayerFee | AckRelayerFee |  CallbackGasPrice |PackageLoad |
    | 2 bytes    |  2 bytes    |  1 byte   |  8 bytes |  1 byte     |  8 bytes  | 32 bytes   | 32 bytes      |  32 bytes         |  len bytes |

    2. ack / failAck package of GNFD -> BSC
    | SrcChainId | DestChainId | ChannelId | Sequence | PackageType | Timestamp | RelayerFee |  CallbackGasPrice |PackageLoad |
    | 2 bytes    |  2 bytes    |  1 byte   |  8 bytes |  1 byte     |  8 bytes  | 32 bytes   |  32 bytes         |  len bytes |
    */
    function _checkPayload(
        bytes calldata payload
    )
        public
        view
        returns (
            bool success,
            uint8 channelId,
            uint64 sequence,
            uint8 packageType,
            uint64 time,
            uint256 relayFee,
            uint256 ackRelayFee,
            bytes memory packageLoad
        )
    {
        if (payload.length < 54) {
            return (false, 0, 0, 0, 0, 0, 0, "");
        }

        bytes memory _payload = payload;
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

        if (packageType == 0) {
            if (payload.length < 86) {
                return (false, 0, 0, 0, 0, 0, 0, "");
            }

            assembly {
                ackRelayFee := mload(add(ptr, 86))
            }
            packageLoad = payload[86:];
        } else {
            ackRelayFee = 0;
            packageLoad = payload[54:];
        }

        success = true;
    }
}
