pragma solidity ^0.8.0;
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract InscriptionProxyAdmin is ProxyAdmin {
    constructor(address _govHubProxy) {
        _transferOwnership(_govHubProxy);
    }
}
