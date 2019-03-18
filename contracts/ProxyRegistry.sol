pragma solidity ^0.5.0;

import "./UserProxy.sol";


// checking if the logic proxy is authorised
contract SystemAdmin {

    address public logicProxyAddr;
    
    modifier isAdmin() {
        require(msg.sender == getAdmin(), "permission-denied");
        _;
    }

    function getAdmin() internal view returns (address) {
        AddressRegistryInterface registry = AddressRegistryInterface(logicProxyAddr);
        return registry.getAddress("admin");
    }

}


contract ProxyRegistry is SystemAdmin {
    
    event Created(address indexed sender, address indexed owner, address proxy);
    
    mapping(address => UserProxy) public proxies;
    bool public guardianEnabled;

    constructor(address _logicProxyAddr) public {
        logicProxyAddr = _logicProxyAddr;
    }

    function build() public returns (UserProxy proxy) {
        proxy = build(msg.sender);
    }

    // deploys a new proxy instance and sets custom owner of proxy
    function build(address owner) public returns (UserProxy proxy) {
        require(
            proxies[owner] == UserProxy(0) || proxies[owner].owner() != owner,
            "multiple-proxy-per-user-not-allowed"
        ); // Not allow new proxy if the user already has one and remains being the owner
        proxy = new UserProxy(owner, logicProxyAddr);
        emit Created(msg.sender, owner, address(proxy));
        proxies[owner] = proxy;
    }

    // msg.sender should always be proxies created via this contract for successful execution
    function updateProxyRecord(address currentOwner, address nextOwner) public {
        require(msg.sender == address(proxies[currentOwner]), "invalid-proxy-or-owner");
        proxies[nextOwner] = proxies[currentOwner];
        proxies[currentOwner] = UserProxy(0);
    }

    function enableGuardian() public isAdmin {
        guardianEnabled = true;
    }

    function disableGuardian() public isAdmin {
        guardianEnabled = false;     
    }

}