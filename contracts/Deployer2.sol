// SPDX-License-Identifier: Apache-2.0.

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "./GnfdProxy.sol";
import "./GnfdProxyAdmin.sol";
import "./Config.sol";
import "./middle-layer/BucketHub.sol";
import "./middle-layer/ObjectHub.sol";
import "./middle-layer/GroupHub.sol";

contract Deployer2 {
    uint16 public immutable gnfdChainId;

    address public immutable proxyAdmin;
    address public immutable proxyBucketHub;
    address public immutable proxyObjectHub;
    address public immutable proxyGroupHub;

    address public implBucketHub;
    address public implObjectHub;
    address public implGroupHub;
    address public addBucketHub;
    address public addObjectHub;
    address public addGroupHub;
    address public bucketToken;
    address public objectToken;
    address public groupToken;
    address public memberToken;

    bool public initialized;
    bool public deployed;

    constructor(uint16 _gnfdChainId, address _deployedProxyAdmin) {
        gnfdChainId = _gnfdChainId;

        /*
            @dev deploy workflow
            a. Generate contracts addresses in advance first while deploy `Deployer`
            b. Write the generated proxy addresses to `Config` contract constants by JS script
            c. Deploy the proxy contracts, checking if they are equal to the generated addresses before
        */
        proxyBucketHub = calcCreateAddress(address(this), uint8(1));
        proxyObjectHub = calcCreateAddress(address(this), uint8(2));
        proxyGroupHub = calcCreateAddress(address(this), uint8(3));

        // 1. proxyAdmin
        proxyAdmin = _deployedProxyAdmin;
    }

    function init(
        address _implBucketHub,
        address _implObjectHub,
        address _implGroupHub,
        address _addBucketHub,
        address _addObjectHub,
        address _addGroupHub,
        address _bucketToken,
        address _objectToken,
        address _groupToken,
        address _memberToken
    ) public {
        require(!initialized, "only not initialized");
        initialized = true;

        require(_isContract(_implBucketHub), "invalid _implBucketHub");
        require(_isContract(_implObjectHub), "invalid _implObjectHub");
        require(_isContract(_implGroupHub), "invalid _implGroupHub");
        require(_isContract(_addBucketHub), "invalid _addBucketHub");
        require(_isContract(_addObjectHub), "invalid _addObjectHub");
        require(_isContract(_addGroupHub), "invalid _addGroupHub");
        require(_isContract(_bucketToken), "invalid _bucketToken");
        require(_isContract(_objectToken), "invalid _objectToken");
        require(_isContract(_groupToken), "invalid _groupToken");
        require(_isContract(_memberToken), "invalid _memberToken");

        implBucketHub = _implBucketHub;
        implObjectHub = _implObjectHub;
        implGroupHub = _implGroupHub;
        addBucketHub = _addBucketHub;
        addObjectHub = _addObjectHub;
        addGroupHub = _addGroupHub;
        bucketToken = _bucketToken;
        objectToken = _objectToken;
        groupToken = _groupToken;
        memberToken = _memberToken;
    }

    function deploy() public {
        require(!deployed, "only not deployed");
        deployed = true;

        // 2. BucketHub
        address deployedProxyBucketHub = address(new GnfdProxy(implBucketHub, proxyAdmin, ""));
        require(deployedProxyBucketHub == proxyBucketHub, "invalid proxyBucketHub address");

        // 3. ObjectHub
        address deployedProxyObjectHub = address(new GnfdProxy(implObjectHub, proxyAdmin, ""));
        require(deployedProxyObjectHub == proxyObjectHub, "invalid proxyObjectHub address");

        // 4. GroupHub
        address deployedProxyGroupHub = address(new GnfdProxy(implGroupHub, proxyAdmin, ""));
        require(deployedProxyGroupHub == proxyGroupHub, "invalid proxyGroupHub address");

        // 5. init contracts
        BucketHub(payable(proxyBucketHub)).initialize(bucketToken, addBucketHub);
        ObjectHub(payable(proxyObjectHub)).initialize(objectToken, addObjectHub);
        GroupHub(payable(proxyGroupHub)).initialize(groupToken, memberToken, addGroupHub);
    }

    function calcCreateAddress(address _deployer, uint8 _nonce) public pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), _deployer, _nonce)))));
    }

    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
}
