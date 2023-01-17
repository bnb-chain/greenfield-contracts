pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "./InscriptionProxy.sol";
import "./InscriptionProxyAdmin.sol";
import "./InscriptionLightClient.sol";
import "./CrossChain.sol";
import "./middle-layer/GovHub.sol";
import "./middle-layer/TokenHub.sol";

contract Deployer {
    uint16 public insChainId;

    address public proxyGovHub;
    address public proxyCrossChain;
    address public proxyTokenHub;
    address public proxyLightClient;
    address public proxyAdmin;

    constructor(uint16 _insChainId) {
        insChainId = _insChainId;

        // 1. proxyAdmin
        proxyAdmin = address(new InscriptionProxyAdmin());
        
        // 2. GovHub, transfer ownership of proxyAdmin to GovHub
        GovHub implGovHub = new GovHub();
        proxyGovHub = address(new InscriptionProxy(
            address(implGovHub),
            proxyAdmin,
            ""
        ));
        // transfer ownership to proxyGovHub
        InscriptionProxyAdmin(proxyAdmin).transferOwnership(address(proxyGovHub));
    }

    function deploy() public {
        // 3. CrossChain
        CrossChain implCrossChain = new CrossChain();
        proxyCrossChain = address(new InscriptionProxy(address(implCrossChain), proxyAdmin, ""));

        // 4. TokenHub
        TokenHub implTokenHub = new TokenHub();
        proxyTokenHub = address(new InscriptionProxy(address(implTokenHub), proxyAdmin, ""));

        // 5. InscriptionLightClient
        InscriptionLightClient implLightClient = new InscriptionLightClient();
        proxyLightClient = address(new InscriptionProxy(address(implLightClient), proxyAdmin, ""));

        // 6. init GovHub, set contracts addresses to GovHub
        GovHub(payable(proxyGovHub)).initialize(proxyAdmin, address(proxyCrossChain), address(proxyLightClient), address(proxyTokenHub));
        TokenHub(payable(proxyTokenHub)).initialize(proxyGovHub);
        CrossChain(payable(proxyCrossChain)).initialize(insChainId, proxyGovHub);
    }
}
