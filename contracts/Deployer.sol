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
import "./middle-layer/BucketHub.sol";
import "./middle-layer/ObjectHub.sol";
import "./middle-layer/GroupHub.sol";

contract Deployer {
    uint16 public immutable gnfdChainId;

    address public immutable proxyAdmin;
    address public immutable proxyGovHub;
    address public immutable proxyCrossChain;
    address public immutable proxyTokenHub;
    address public immutable proxyLightClient;
    address public immutable proxyRelayerHub;
    address public immutable proxyBucketHub;
    address public immutable proxyObjectHub;
    address public immutable proxyGroupHub;

    bytes public initConsensusStateBytes;
    address public implGovHub;
    address public implCrossChain;
    address public implTokenHub;
    address public implLightClient;
    address public implRelayerHub;
    address public implBucketHub;
    address public implObjectHub;
    address public implGroupHub;
    address public bucketToken;
    address public objectToken;
    address public groupToken;
    address public memberToken;

    bool public initializedPart1;
    bool public initializedPart2;
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
        proxyBucketHub = calcCreateAddress(address(this), uint8(7));
        proxyObjectHub = calcCreateAddress(address(this), uint8(8));
        proxyGroupHub = calcCreateAddress(address(this), uint8(9));

        // 1. proxyAdmin
        address deployedProxyAdmin = address(new GnfdProxyAdmin());
        require(deployedProxyAdmin == proxyAdmin, "invalid proxyAdmin address");
    }

    function initAddrsPart1(
        address _implGovHub,
        address _implCrossChain,
        address _implTokenHub,
        address _implLightClient,
        address _implRelayerHub
    ) public {
        require(!initializedPart1, "only not initializedPart1");
        initializedPart1 = true;

        require(_isContract(_implGovHub), "invalid _implCrossChain");
        require(_isContract(_implCrossChain), "invalid _implCrossChain");
        require(_isContract(_implTokenHub), "invalid _implTokenHub");
        require(_isContract(_implLightClient), "invalid _implLightClient");
        require(_isContract(_implRelayerHub), "invalid _implRelayerHub");

        implGovHub = _implGovHub;
        implCrossChain = _implCrossChain;
        implTokenHub = _implTokenHub;
        implLightClient = _implLightClient;
        implRelayerHub = _implRelayerHub;
    }

    function initAddrsPart2(
        address _implBucketHub,
        address _implObjectHub,
        address _implGroupHub,
        address _bucketToken,
        address _objectToken,
        address _groupToken,
        address _memberToken
    ) public {
        require(!initializedPart2, "only not initializedPart2");
        initializedPart2 = true;

        require(_isContract(_implBucketHub), "invalid _implBucketHub");
        require(_isContract(_implObjectHub), "invalid _implObjectHub");
        require(_isContract(_implGroupHub), "invalid _implGroupHub");
        require(_isContract(_bucketToken), "invalid _bucketToken");
        require(_isContract(_objectToken), "invalid _objectToken");
        require(_isContract(_groupToken), "invalid _groupToken");
        require(_isContract(_memberToken), "invalid _memberToken");

        implBucketHub = _implBucketHub;
        implObjectHub = _implObjectHub;
        implGroupHub = _implGroupHub;
        bucketToken = _bucketToken;
        objectToken = _objectToken;
        groupToken = _groupToken;
        memberToken = _memberToken;
    }

    function deploy(bytes calldata _initConsensusStateBytes) public {
        require(!deployed, "only not deployed");
        deployed = true;

        initConsensusStateBytes = _initConsensusStateBytes;

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

        // 7. BucketHub
        address deployedProxyBucketHub = address(new GnfdProxy(implBucketHub, proxyAdmin, ""));
        require(deployedProxyBucketHub == proxyBucketHub, "invalid proxyBucketHub address");

        // 8. ObjectHub
        address deployedProxyObjectHub = address(new GnfdProxy(implObjectHub, proxyAdmin, ""));
        require(deployedProxyObjectHub == proxyObjectHub, "invalid proxyObjectHub address");

        // 9. GroupHub
        address deployedProxyGroupHub = address(new GnfdProxy(implGroupHub, proxyAdmin, ""));
        require(deployedProxyGroupHub == proxyGroupHub, "invalid proxyGroupHub address");

        // 10. init GovHub, set contracts addresses to GovHub
        CrossChain(payable(proxyCrossChain)).initialize(gnfdChainId);
        TokenHub(payable(proxyTokenHub)).initialize();
        GnfdLightClient(payable(proxyLightClient)).initialize(_initConsensusStateBytes);
        RelayerHub(payable(proxyRelayerHub)).initialize();
        BucketHub(payable(proxyBucketHub)).initialize(bucketToken);
        ObjectHub(payable(proxyObjectHub)).initialize(objectToken);
        GroupHub(payable(proxyGroupHub)).initialize(groupToken, memberToken);

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
            Config(deployedProxyCrossChain).BUCKET_HUB() == proxyBucketHub, "invalid proxyBucketHub address on Config"
        );
        require(
            Config(deployedProxyCrossChain).OBJECT_HUB() == proxyObjectHub, "invalid proxyObjectHub address on Config"
        );
        require(Config(deployedProxyCrossChain).GROUP_HUB() == proxyGroupHub, "invalid proxyGroupHub address on Config");
    }

    function calcCreateAddress(address _deployer, uint8 _nonce) public pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), _deployer, _nonce)))));
    }

    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
}
