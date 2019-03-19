pragma solidity ^0.5.0;

import "./UserWallet.sol";


/**
 * @title Address Registry
 */
contract AddressRegistry {
    event LogSetAddress(string name, address addr);

    mapping(bytes32 => address) registry;

    constructor() public {
        registry[keccak256(abi.encodePacked("admin"))] = msg.sender;
        registry[keccak256(abi.encodePacked("owner"))] = msg.sender;
    }

    /**
     * @dev get the address from system registry 
     */
    function getAddress(string memory name) public view returns(address) {
        return registry[keccak256(abi.encodePacked(name))];
    }

    /**
     * @dev set new address in system registry 
     */
    function setAddress(string memory name, address addr) public {
        require(
            msg.sender == getAddress("admin") || 
            msg.sender == getAddress("owner"),
            "permission-denied"
        );
        registry[keccak256(abi.encodePacked(name))] = addr;
        emit LogSetAddress(name, addr);
    }

    modifier isAdmin() {
        require(msg.sender == getAddress("admin"), "permission-denied");
        _;
    }

}


/**
 * @title Logic Registry
 */
contract LogicRegistry is AddressRegistry {

    event LogSetDefaultLogic(address logicAddr);
    event LogSetLogic(address logicAddr, bool isLogic);

    mapping(address => bool) public defaultLogicProxies;
    mapping(address => bool) public logicProxies;

    /**
     * @dev get the boolean of the logic proxy contract
     * @param logicAddr is the logic proxy address
     */
    function getLogic(address logicAddr) public view returns (bool) {
        if (defaultLogicProxies[logicAddr]) {
            return true;
        } else if (logicProxies[logicAddr]) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev this sets the default logic proxy to true
     * @param logicAddr is the default logic proxy address
     */
    function setDefaultLogic(address logicAddr) public isAdmin {
        defaultLogicProxies[logicAddr] = true;
        emit LogSetDefaultLogic(logicAddr);
    }

    /**
     * @dev this updates the boolean of the logic proxy
     * @param logicAddr is the logic proxy address
     * @param isLogic is the boolean to set for the logic proxy
     */
    function setLogic(address logicAddr, bool isLogic) public isAdmin {
        logicProxies[logicAddr] = true;
        emit LogSetLogic(logicAddr, isLogic);
    }

}


/**
 * @title User Wallet Registry
 */
contract ProxyRegistry is LogicRegistry {
    
    event Created(address indexed sender, address indexed owner, address proxy);
    
    mapping(address => UserWallet) public proxies;
    bool public guardianEnabled;

    /**
     * @dev deploys a new proxy instance and sets msg.sender as owner of proxy
     */
    function build() public returns (UserWallet proxy) {
        proxy = build(msg.sender);
    }

    /**
     * @dev deploys a new proxy instance and sets custom owner of proxy
     * Throws if the owner already have a UserWallet
     */
    function build(address owner) public returns (UserWallet proxy) {
        require(proxies[owner] == UserWallet(0), "multiple-proxy-per-user-not-allowed");
        proxy = new UserWallet(owner);
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
        proxies[currentOwner] = UserWallet(0);
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