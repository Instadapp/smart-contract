pragma solidity ^0.5.0;

import "./UserProxy.sol";


contract ProxyRegistry {
    event Created(address indexed sender, address indexed owner, address proxy);
    mapping(address => UserProxy) public proxies;
    address public logicProxyAddr;

    constructor(address logicProxyAddr_) public {
        logicProxyAddr = logicProxyAddr_;
    }

    function build(uint activeDays) public returns (UserProxy proxy) {
        proxy = build(msg.sender, activeDays);
    }

    // deploys a new proxy instance and sets custom owner of proxy
    function build(address owner, uint activeDays) public returns (UserProxy proxy) {
        require(
            proxies[owner] == UserProxy(0) || proxies[owner].owner() != owner, 
            "multiple-proxy-per-user-not-allowed"
        ); // Not allow new proxy if the user already has one and remains being the owner
        
        proxy = new UserProxy(logicProxyAddr, activeDays);
        emit Created(msg.sender, owner, address(proxy));
        proxy.setOwner(owner);
        proxies[owner] = proxy;
    }
}
