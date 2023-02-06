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
    bytes public initConsensusStateBytes;

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

    constructor(uint16 _gnfdChainId) {
        gnfdChainId = _gnfdChainId;

        // 1. proxyAdmin
        proxyAdmin = address(new GnfdProxyAdmin());

        // 2. GovHub, transfer ownership of proxyAdmin to GovHub
        implGovHub = address(new GovHub());
        proxyGovHub = address(new GnfdProxy(implGovHub, proxyAdmin, ""));
        // transfer ownership to proxyGovHub
        GnfdProxyAdmin(proxyAdmin).transferOwnership(address(proxyGovHub));
    }

    function deploy(
        bytes calldata _initConsensusStateBytes,
        address _implCrossChain,
        address _implTokenHub,
        address _implLightClient,
        address _implRelayerHub
    ) public {
        require(_isContract(_implCrossChain), "invalid _implCrossChain");
        require(_isContract(_implTokenHub), "invalid _implTokenHub");
        require(_isContract(_implLightClient), "invalid _implLightClient");
        require(_isContract(_implRelayerHub), "invalid _implRelayerHub");

        initConsensusStateBytes = _initConsensusStateBytes;
        implCrossChain = _implCrossChain;
        implTokenHub = _implTokenHub;
        implLightClient = _implLightClient;
        implRelayerHub = _implRelayerHub;

        // 4. CrossChain
        proxyCrossChain = address(new GnfdProxy(implCrossChain, proxyAdmin, ""));

        // 5. TokenHub
        proxyTokenHub = address(new GnfdProxy(implTokenHub, proxyAdmin, ""));

        // 6. GnfdLightClient
        proxyLightClient = address(new GnfdProxy(address(implLightClient), proxyAdmin, ""));

        // 7. RelayerHub
        proxyRelayerHub = address(new GnfdProxy(address(implRelayerHub), proxyAdmin, ""));

        // 8. init GovHub, set contracts addresses to GovHub
        CrossChain(payable(proxyCrossChain)).initialize(gnfdChainId);
        TokenHub(payable(proxyTokenHub)).initialize();
        GnfdLightClient(payable(proxyLightClient)).initialize(_initConsensusStateBytes);
        RelayerHub(payable(proxyRelayerHub)).initialize();
    }

    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
}
