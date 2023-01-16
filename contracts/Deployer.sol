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
    address public proxyGovHub;
    address public proxyCrossChain;
    address public proxyTokenHub;
    address public proxyLightClient;

    constructor(uint16 insChainId) {
        // 1. proxyAdmin
        ProxyAdmin proxyAdmin = new InscriptionProxyAdmin();
        
        // 2. GovHub, transfer ownership of proxyAdmin to GovHub
        GovHub implGovHub = new GovHub();
        proxyGovHub = address(new InscriptionProxy(
            address(implGovHub),
            address(proxyAdmin),
            ""
        ));
        // transfer ownership to proxyGovHub
        proxyAdmin.transferOwnership(address(proxyGovHub));

        // 3. CrossChain
        CrossChain implCrossChain = new CrossChain();
        proxyCrossChain = address(new InscriptionProxy(
            address(implCrossChain),
            address(proxyAdmin),
            abi.encodeWithSignature("initialize(uint32,address)", insChainId, proxyGovHub)
        ));

        // 4. TokenHub 
        TokenHub implTokenHub = new TokenHub();
        proxyTokenHub = address(new InscriptionProxy(
            address(implTokenHub),
            address(proxyAdmin),
            abi.encodeWithSignature("initialize(address)", proxyGovHub)
        ));

        // 5. InscriptionLightClient
        InscriptionLightClient implLightClient = new InscriptionLightClient();
        proxyLightClient = address(new InscriptionProxy(
            address(implLightClient),
            address(proxyAdmin),
            ""
        ));

        // 6. init GovHub, set contracts addresses to GovHub
        GovHub(address(proxyGovHub)).initialize(
            address(proxyAdmin),
            address(proxyCrossChain),
            address(proxyLightClient),
            address(proxyTokenHub)
        );
    }
}
