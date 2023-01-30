pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "./GnfdProxy.sol";
import "./GnfdProxyAdmin.sol";
import "./GnfdLightClient.sol";
import "./CrossChain.sol";
import "./middle-layer/GovHub.sol";
import "./middle-layer/TokenHub.sol";

contract Deployer {
    uint16 public gnfdChainId;
    bytes public blsPubKeys;
    address[] public relayers;

    address public proxyGovHub;
    address public proxyCrossChain;
    address public proxyTokenHub;
    address public proxyLightClient;
    address public proxyAdmin;

    address private implCrossChain;
    address private implTokenHub;
    address private implLightClient;

    constructor(uint16 _gnfdChainId, bytes memory _blsPubKeys, address[] memory _relayers) {
        gnfdChainId = _gnfdChainId;
        blsPubKeys = _blsPubKeys;
        relayers = _relayers;

        // 1. proxyAdmin
        proxyAdmin = address(new GnfdProxyAdmin());

        // 2. GovHub, transfer ownership of proxyAdmin to GovHub
        GovHub implGovHub = new GovHub();
        proxyGovHub = address(
            new GnfdProxy(
                                    address(implGovHub),
                                    proxyAdmin,
                                    ""
                                )
        );
        // transfer ownership to proxyGovHub
        GnfdProxyAdmin(proxyAdmin).transferOwnership(address(proxyGovHub));

        implCrossChain = address(new CrossChain());
        implTokenHub = address(new TokenHub());
        implLightClient = address(new GnfdLightClient());
    }

    function deploy() public {
        // 3. CrossChain
        proxyCrossChain = address(new GnfdProxy(implCrossChain, proxyAdmin, ""));

        // 4. TokenHub
        proxyTokenHub = address(new GnfdProxy(implTokenHub, proxyAdmin, ""));

        // 5. GnfdLightClient
        proxyLightClient = address(new GnfdProxy(address(implLightClient), proxyAdmin, ""));

        // 6. init GovHub, set contracts addresses to GovHub
        GovHub(payable(proxyGovHub)).initialize(
            proxyAdmin, address(proxyCrossChain), address(proxyLightClient), address(proxyTokenHub)
        );
        TokenHub(payable(proxyTokenHub)).initialize(proxyGovHub);
        CrossChain(payable(proxyCrossChain)).initialize(gnfdChainId, proxyGovHub);
        GnfdLightClient(payable(proxyLightClient)).initialize(blsPubKeys, relayers);
    }
}
