pragma solidity ^0.5.0;

import "./UserProxy.sol";


// checking if the logic proxy is authorised
contract SystemAdmin {

    address public addrRegistry;
    
    modifier isAdmin() {
        require(msg.sender == getAdmin(), "permission-denied");
        _;
    }

    /**
     * @dev get the system admin
     */
    function getAdmin() internal view returns (address) {
        AddressRegistryInterface registry = AddressRegistryInterface(addrRegistry);
        return registry.getAddress("admin");
    }

}


contract ProxyRegistry is SystemAdmin {
    
    event Created(address indexed sender, address indexed owner, address proxy);
    
    mapping(address => UserProxy) public proxies;
    bool public guardianEnabled;

    constructor(address _addrRegistry) public {
        addrRegistry = _addrRegistry;
    }

    /**
     * @dev deploys a new proxy instance and sets msg.sender as owner of proxy
     */
    function build() public returns (UserProxy proxy) {
        proxy = build(msg.sender);
    }

    /**
     * @dev deploys a new proxy instance and sets custom owner of proxy
     */
    function build(address owner) public returns (UserProxy proxy) {
        require(
            proxies[owner] == UserProxy(0) || proxies[owner].owner() != owner,
            "multiple-proxy-per-user-not-allowed"
        ); // Not allow new proxy if the user already has one and remains being the owner
        proxy = new UserProxy(owner, addrRegistry);
        emit Created(msg.sender, owner, address(proxy));
        proxies[owner] = proxy;
    }

    /**
     * @dev update the proxy record whenever owner changed on any proxy
     * Throws if msg.sender is not a proxy contract created via this contract
     */
    function updateProxyRecord(address currentOwner, address nextOwner) public {
        require(msg.sender == address(proxies[currentOwner]), "invalid-proxy-or-owner");
        proxies[nextOwner] = proxies[currentOwner];
        proxies[currentOwner] = UserProxy(0);
    }

    /**
     * @dev enable guardian in overall system
     */
    function enableGuardian() public isAdmin {
        guardianEnabled = true;
    }

    /**
     * @dev disable guardian in overall system
     */
    function disableGuardian() public isAdmin {
        guardianEnabled = false;     
    }

}