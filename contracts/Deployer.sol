pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "./GnfdProxy.sol";
import "./GnfdProxyAdmin.sol";
import "./GnfdLightClient.sol";
import "./CrossChain.sol";
import "./RelayerHub.sol";
import "./middle-layer/GovHub.sol";
import "./middle-layer/TokenHub.sol";

contract Deployer {
    uint16 public gnfdChainId;
    bytes public blsPubKeys;
    address[] public relayers;

    address public proxyAdmin;

    address public proxyGovHub;
    address public proxyCrossChain;
    address public proxyTokenHub;
    address public proxyLightClient;
    address public proxyRelayerHub;

    address private implGovHub;
    address private implCrossChain;
    address private implTokenHub;
    address private implLightClient;
    address private implRelayerHub;

    constructor(uint16 _gnfdChainId, bytes memory _blsPubKeys, address[] memory _relayers) {
        gnfdChainId = _gnfdChainId;
        blsPubKeys = _blsPubKeys;
        relayers = _relayers;

        // 1. proxyAdmin
        proxyAdmin = address(new GnfdProxyAdmin());

        // 2. GovHub, transfer ownership of proxyAdmin to GovHub
        implGovHub = address(new GovHub());
        proxyGovHub = address(new GnfdProxy(implGovHub, proxyAdmin, ""));
        // transfer ownership to proxyGovHub
        GnfdProxyAdmin(proxyAdmin).transferOwnership(address(proxyGovHub));

        // 3. deploy implementation contracts
        implCrossChain = address(new CrossChain());
        implTokenHub = address(new TokenHub());
        implLightClient = address(new GnfdLightClient());
        implRelayerHub = address(new RelayerHub());
    }

    function deploy() public {
        // 4. CrossChain
        proxyCrossChain = address(new GnfdProxy(implCrossChain, proxyAdmin, ""));

        // 5. TokenHub
        proxyTokenHub = address(new GnfdProxy(implTokenHub, proxyAdmin, ""));

        // 6. GnfdLightClient
        proxyLightClient = address(new GnfdProxy(address(implLightClient), proxyAdmin, ""));

        // 7. RelayerHub
        proxyRelayerHub = address(new GnfdProxy(address(implRelayerHub), proxyAdmin, ""));

        // 8. init GovHub, set contracts addresses to GovHub
        GovHub(payable(proxyGovHub)).initialize(
            proxyAdmin,
            address(proxyCrossChain),
            address(proxyTokenHub),
            address(proxyLightClient),
            address(proxyRelayerHub)
        );
        CrossChain(payable(proxyCrossChain)).initialize(gnfdChainId, proxyGovHub);
        TokenHub(payable(proxyTokenHub)).initialize(proxyGovHub);
        GnfdLightClient(payable(proxyLightClient)).initialize("");
        RelayerHub(payable(proxyRelayerHub)).initialize(proxyGovHub);
    }
}
