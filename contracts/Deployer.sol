// SPDX-License-Identifier: Apache-2.0.

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
import "./middle-layer/CredentialHub.sol";
import "./crossChain-credentials/ERC721NonTransferable.sol";

contract Deployer {
    uint16 public immutable gnfdChainId;

    address public immutable proxyAdmin;
    address public immutable proxyGovHub;
    address public immutable proxyCrossChain;
    address public immutable proxyTokenHub;
    address public immutable proxyLightClient;
    address public immutable proxyRelayerHub;
    address public immutable proxyCredentialHub;

    address public immutable bucket;
    address public immutable object;
    address public immutable group;

    bytes public initConsensusStateBytes;
    address public implGovHub;
    address public implCrossChain;
    address public implTokenHub;
    address public implLightClient;
    address public implRelayerHub;
    address public implCredentialHub;

    bool public deployed;

    constructor(uint16 _gnfdChainId) {
        gnfdChainId = _gnfdChainId;

        /*
            @dev deploy workflow
            a. Generate contracts addresses in advance first while deploy `Deployer`
            b. Write the generated proxy addresses to `Config` contract constants by JS script
            c. Deploy the proxy contracts, checking if they are equal to the generated addresses before
        */
        proxyAdmin = calcCreateAddress(address(this), uint8(1));
        proxyGovHub = calcCreateAddress(address(this), uint8(2));
        proxyCrossChain = calcCreateAddress(address(this), uint8(3));
        proxyTokenHub = calcCreateAddress(address(this), uint8(4));
        proxyLightClient = calcCreateAddress(address(this), uint8(5));
        proxyRelayerHub = calcCreateAddress(address(this), uint8(6));
        proxyCredentialHub = calcCreateAddress(address(this), uint8(7));

        bucket = address(new ERC721NonTransferable("GreenField-Bucket", "Bucket", proxyCredentialHub));
        object = address(new ERC721NonTransferable("GreenField-Object", "Object", proxyCredentialHub));
        group = address(new ERC721NonTransferable("GreenField-Group", "Group", proxyCredentialHub));

        // 1. proxyAdmin
        address deployedProxyAdmin = address(new GnfdProxyAdmin());
        require(deployedProxyAdmin == proxyAdmin, "invalid proxyAdmin address");
    }

    function deploy(
        bytes calldata _initConsensusStateBytes,
        address _implGovHub,
        address _implCrossChain,
        address _implTokenHub,
        address _implLightClient,
        address _implRelayerHub,
        address _implCredentialHub
    ) public {
        require(!deployed, "only not deployed");
        deployed = true;

        require(_isContract(_implGovHub), "invalid _implCrossChain");
        require(_isContract(_implCrossChain), "invalid _implCrossChain");
        require(_isContract(_implTokenHub), "invalid _implTokenHub");
        require(_isContract(_implLightClient), "invalid _implLightClient");
        require(_isContract(_implRelayerHub), "invalid _implRelayerHub");
        require(_isContract(_implCredentialHub), "invalid _implCredentialHub");

        initConsensusStateBytes = _initConsensusStateBytes;
        implGovHub = _implGovHub;
        implCrossChain = _implCrossChain;
        implTokenHub = _implTokenHub;
        implLightClient = _implLightClient;
        implRelayerHub = _implRelayerHub;
        implCredentialHub = _implCredentialHub;

        // 2. GovHub, transfer ownership of proxyAdmin to GovHub
        address deployedProxyGovHub = address(new GnfdProxy(implGovHub, proxyAdmin, ""));
        require(deployedProxyGovHub == proxyGovHub, "invalid proxyGovHub address");

        // transfer ownership to proxyGovHub
        GnfdProxyAdmin(proxyAdmin).transferOwnership(proxyGovHub);
        require(GnfdProxyAdmin(proxyAdmin).owner() == proxyGovHub, "invalid proxyAdmin owner");

        // 3. CrossChain
        address deployedProxyCrossChain = address(new GnfdProxy(implCrossChain, proxyAdmin, ""));
        require(deployedProxyCrossChain == proxyCrossChain, "invalid proxyCrossChain address");

        // 4. TokenHub
        address deployedProxyTokenHub = address(new GnfdProxy(implTokenHub, proxyAdmin, ""));
        require(deployedProxyTokenHub == proxyTokenHub, "invalid proxyTokenHub address");

        // 5. GnfdLightClient
        address deployedProxyLightClient = address(new GnfdProxy(implLightClient, proxyAdmin, ""));
        require(deployedProxyLightClient == proxyLightClient, "invalid proxyLightClient address");

        // 6. RelayerHub
        address deployedProxyRelayerHub = address(new GnfdProxy(implRelayerHub, proxyAdmin, ""));
        require(deployedProxyRelayerHub == proxyRelayerHub, "invalid proxyRelayerHub address");

        // 7. CredentialHub
        address deployedProxyCredentialHub = address(new GnfdProxy(implCredentialHub, proxyAdmin, ""));
        require(deployedProxyCredentialHub == proxyCredentialHub, "invalid proxyCredentialHub address");

        // 8. init GovHub, set contracts addresses to GovHub
        CrossChain(payable(proxyCrossChain)).initialize(gnfdChainId);
        TokenHub(payable(proxyTokenHub)).initialize();
        GnfdLightClient(payable(proxyLightClient)).initialize(_initConsensusStateBytes);
        RelayerHub(payable(proxyRelayerHub)).initialize();
        CredentialHub(payable(proxyCredentialHub)).initialize(bucket, object, group);

        require(Config(deployedProxyCrossChain).PROXY_ADMIN() == proxyAdmin, "invalid proxyAdmin address on Config");
        require(Config(deployedProxyCrossChain).GOV_HUB() == proxyGovHub, "invalid proxyGovHub address on Config");
        require(
            Config(deployedProxyCrossChain).CROSS_CHAIN() == proxyCrossChain,
            "invalid proxyCrossChain address on Config"
        );
        require(Config(deployedProxyCrossChain).TOKEN_HUB() == proxyTokenHub, "invalid proxyTokenHub address on Config");
        require(
            Config(deployedProxyCrossChain).LIGHT_CLIENT() == proxyLightClient,
            "invalid proxyLightClient address on Config"
        );
        require(
            Config(deployedProxyCrossChain).RELAYER_HUB() == proxyRelayerHub,
            "invalid proxyRelayerHub address on Config"
        );
        require(
            Config(deployedProxyCrossChain).CREDENTIAL_HUB() == proxyCredentialHub,
            "invalid proxyCredentialHub address on Config"
        );
    }

    function calcCreateAddress(address _deployer, uint8 _nonce) public pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), _deployer, _nonce)))));
    }

    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
}
