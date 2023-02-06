pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../contracts/Deployer.sol";
import "../contracts/CrossChain.sol";
import "../contracts/GnfdProxy.sol";
import "../contracts/GnfdProxyAdmin.sol";
import "../contracts/GnfdLightClient.sol";
import "../contracts/middle-layer/GovHub.sol";
import "../contracts/middle-layer/TokenHub.sol";

contract CrossChainTest is Test {
    uint16 public constant gnfdChainId = 1;
    bytes public constant initConsensusStateBytes = "677265656e6669656c645f393030302d313231000000000000000000000000000000000000000001a5f1af4874227f1cdbe5240259a365ad86484a4255bfd65e2a0222d733fcdbc320cc466ee9412ddd49e0fff04cdb41bade2b7622f08b6bdacac94d4de03bdb970000000000002710d5e63aeee6e6fa122a6a23a6e0fca87701ba1541aa2d28cbcd1ea3a63479f6fb260a3d755853e6a78cfa6252584fee97b2ec84a9d572ee4a5d3bc1558bb98a4b370fb8616b0b523ee91ad18a63d63f21e0c40a83ef15963f4260574ca5159fd90a1c527000000000000027106fd1ceb5a48579f322605220d4325bd9ff90d5fab31e74a881fc78681e3dfa440978d2b8be0708a1cbbca2c660866216975fdaf0e9038d9b7ccbf9731f43956dba7f2451919606ae20bf5d248ee353821754bcdb456fd3950618fda3e32d3d0fb990eeda000000000000271097376a436bbf54e0f6949b57aa821a90a749920ab32979580ea04984a2be033599c20c7a0c9a8d121b57f94ee05f5eda5b36c38f6e354c89328b92cdd1de33b64d3a0867";

    Deployer public deployer;
    GovHub public govHub;
    CrossChain public crossChain;
    TokenHub public tokenHub;
    GnfdLightClient public lightClient;

    address private developer = 0x0000000000000000000000000000000012345678;
    address private user1 = 0x1000000000000000000000000000000012345678;

    function setUp() public {
        deployer = new Deployer(gnfdChainId);

        // 3. deploy implementation contracts
        address implCrossChain = address(new CrossChain());
        address implTokenHub = address(new TokenHub());
        address implLightClient = address(new GnfdLightClient());
        address implRelayerHub = address(new RelayerHub());
        deployer.deploy(initConsensusStateBytes, implCrossChain, implTokenHub, implLightClient, implRelayerHub);

        govHub = GovHub(payable(deployer.proxyGovHub()));
        crossChain = CrossChain(payable(deployer.proxyCrossChain()));
        tokenHub = TokenHub(payable(deployer.proxyTokenHub()));
        lightClient = GnfdLightClient(payable(deployer.proxyLightClient()));

        vm.deal(developer, 10000 ether);
    }

    function test_transferOut() public {
        address receipt = user1;
        uint256 amount = 1 ether;
        tokenHub.transferOut{value: amount + 1 ether}(receipt, amount);
    }

    function test_decode() public {
        bytes memory _payload =
            hex"eb0a94fa1a93d8fe3834d33a6e79f795859367ca1229669450e3f659803ffdf09813bdef9be4a14ad85f31f8";
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
    | SrcChainId | DestChainId | ChannelId | Sequence | PackageType | Timestamp | SynRelayerFee | AckRelayerFee(optional) | PackageLoad |
    | 2 bytes    |  2 bytes    |  1 byte   |  8 bytes |  1 byte     |  8 bytes  | 32 bytes      | 32 bytes / 0 bytes      |   len bytes |*/
    function _checkPayload(bytes calldata payload)
        public
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
