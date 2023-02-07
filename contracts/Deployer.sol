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
    uint16 public immutable gnfdChainId;

    address public immutable proxyAdmin;
    address public immutable proxyGovHub;
    address public immutable proxyCrossChain;
    address public immutable proxyTokenHub;
    address public immutable proxyLightClient;
    address public immutable proxyRelayerHub;

    bytes public initConsensusStateBytes;
    address public implGovHub;
    address public implCrossChain;
    address public implTokenHub;
    address public implLightClient;
    address public implRelayerHub;

    bool public deployed;

    constructor(uint16 _gnfdChainId) {
        gnfdChainId = _gnfdChainId;

        /*
            @dev deploy workflow
            a. Generate contracts addresses in advance first while deploy `Deployer`
            b. Write the generated proxy addresses to `Config` contract constants in js script
            c. Deploy the proxy contracts, checking if they are equal to the generated addresses before
        */
        proxyAdmin =
            address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), address(this), uint8(1))))));
        proxyGovHub =
            address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), address(this), uint8(2))))));
        proxyCrossChain =
            address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), address(this), uint8(3))))));
        proxyTokenHub =
            address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), address(this), uint8(4))))));
        proxyLightClient =
            address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), address(this), uint8(5))))));
        proxyRelayerHub =
            address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), address(this), uint8(6))))));

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
        address _implRelayerHub
    )
        public
    {
        require(!deployed, "only not deployed");
        deployed = true;

        require(_isContract(_implGovHub), "invalid _implCrossChain");
        require(_isContract(_implCrossChain), "invalid _implCrossChain");
        require(_isContract(_implTokenHub), "invalid _implTokenHub");
        require(_isContract(_implLightClient), "invalid _implLightClient");
        require(_isContract(_implRelayerHub), "invalid _implRelayerHub");

        initConsensusStateBytes = _initConsensusStateBytes;
        implGovHub = _implGovHub;
        implCrossChain = _implCrossChain;
        implTokenHub = _implTokenHub;
        implLightClient = _implLightClient;
        implRelayerHub = _implRelayerHub;

        // 2. GovHub, transfer ownership of proxyAdmin to GovHub
        address deployedProxyGovHub = address(new GnfdProxy(implGovHub, proxyAdmin, ""));
        require(deployedProxyGovHub == proxyGovHub, "invalid proxyGovHub address");

        // transfer ownership to proxyGovHub
        GnfdProxyAdmin(proxyAdmin).transferOwnership(address(proxyGovHub));

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

        // 7. init GovHub, set contracts addresses to GovHub
        CrossChain(payable(proxyCrossChain)).initialize(gnfdChainId);
        TokenHub(payable(proxyTokenHub)).initialize();
        GnfdLightClient(payable(proxyLightClient)).initialize(_initConsensusStateBytes);
        RelayerHub(payable(proxyRelayerHub)).initialize();

        require(Config(deployedProxyCrossChain).PROXY_ADMIN() == proxyAdmin, "invalid proxyAdmin address on Config");
        require(Config(deployedProxyCrossChain).GOV_HUB() == proxyGovHub, "invalid proxyGovHub address on Config");
        require(
            Config(deployedProxyCrossChain).CROSS_CHAIN() == proxyCrossChain, "invalid proxyCrossChain address on Config"
        );
        require(Config(deployedProxyCrossChain).TOKEN_HUB() == proxyTokenHub, "invalid proxyTokenHub address on Config");
        require(
            Config(deployedProxyCrossChain).LIGHT_CLIENT() == proxyLightClient,
            "invalid proxyLightClient address on Config"
        );
        require(
            Config(deployedProxyCrossChain).RELAYER_HUB() == proxyRelayerHub, "invalid proxyRelayerHub address on Config"
        );
    }

    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
}
