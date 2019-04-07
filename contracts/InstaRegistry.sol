pragma solidity ^0.5.2;

import "./UserWallet.sol";


/// @title AddressRegistry
/// @notice 
/// @dev 
contract AddressRegistry {
    event LogSetAddress(string name, address addr);

    /// @notice Registry of role and address
    mapping(bytes32 => address) registry;

    /**
     * @dev Check if msg.sender is admin or owner.
     */
    modifier isAdmin() {
        require(
            msg.sender == getAddress("admin") || 
            msg.sender == getAddress("owner"),
            "permission-denied"
        );
        _;
    }

    /// @dev Get the address from system registry 
    /// @param _name (string)
    /// @return  (address) Returns address based on role
    function getAddress(string memory _name) public view returns(address) {
        return registry[keccak256(abi.encodePacked(_name))];
    }

    /// @dev Set new address in system registry 
    /// @param _name (string) Role name
    /// @param _userAddress (string) User Address
    function setAddress(string memory _name, address _userAddress) public isAdmin {
        registry[keccak256(abi.encodePacked(_name))] = _userAddress;
        emit LogSetAddress(_name, _userAddress);
    }
}


/// @title LogicRegistry
/// @notice
/// @dev LogicRegistry 
contract LogicRegistry is AddressRegistry {

    event LogEnableStaticLogic(address logicAddress);
    event LogEnableLogic(address logicAddress);
    event LogDisableLogic(address logicAddress);

    /// @notice Map of static proxy state
    mapping(address => bool) public logicProxiesStatic;
    
    /// @notice Map of logic proxy state
    mapping(address => bool) public logicProxies;

    /// @dev 
    /// @param _logicAddress (address)
    /// @return  (bool)
    function logic(address _logicAddress) public view returns (bool) {
        if (logicProxiesStatic[_logicAddress] || logicProxies[_logicAddress]) {
            return true;
        }
        return false;
    }

    /// @dev 
    /// @param _logicAddress (address)
    /// @return  (bool)
    function logicStatic(address _logicAddress) public view returns (bool) {
        if (logicProxiesStatic[_logicAddress]) {
            return true;
        }
        return false;
    }

    /// @dev Sets the static logic proxy to true
    /// static proxies mostly contains the logic for withdrawal of assets
    /// and can never be false to freely let user withdraw their assets
    /// @param _logicAddress (address)
    function enableStaticLogic(address _logicAddress) public isAdmin {
        logicProxiesStatic[_logicAddress] = true;
        emit LogEnableStaticLogic(_logicAddress);
    }

    /// @dev Enable logic proxy address
    /// @param _logicAddress (address)
    function enableLogic(address _logicAddress) public isAdmin {
        logicProxies[_logicAddress] = true;
        emit LogEnableLogic(_logicAddress);
    }

    /// @dev Disable logic proxy address
    /// @param _logicAddress (address)
    function disableLogic(address _logicAddress) public isAdmin {
        logicProxies[_logicAddress] = false;
        emit LogDisableLogic(_logicAddress);
    }

}


/**
 * @dev Deploys a new proxy instance and sets msg.sender as owner of proxy
 */
contract WalletRegistry is LogicRegistry {
    
    event Created(address indexed sender, address indexed owner, address proxy);
    event LogRecord(address indexed currentOwner, address indexed nextOwner, address proxy);
    
    /// @notice Address to UserWallet proxy map
    mapping(address => UserWallet) public proxies;
    
    /// @dev Deploys a new proxy instance and sets custom owner of proxy
    /// Throws if the owner already have a UserWallet
    /// @return proxy ()
    function build() public returns (UserWallet proxy) {
        proxy = build(msg.sender);
    }

    /// @dev update the proxy record whenever owner changed on any proxy
    /// Throws if msg.sender is not a proxy contract created via this contract
    /// @return proxy () UserWallet
    function build(address _owner) public returns (UserWallet proxy) {
        require(proxies[_owner] == UserWallet(0), "multiple-proxy-per-user-not-allowed");
        proxy = new UserWallet();
        proxies[address(this)] = proxy; // will be changed via record() in next line execution
        proxy.setOwner(_owner);
        emit Created(msg.sender, _owner, address(proxy));
    }

    /// @dev Transafers ownership
    /// @param _currentOwner (address) Current Owner
    /// @param _nextOwner (address) Next Owner
    function record(address _currentOwner, address _nextOwner) public {
        require(msg.sender == address(proxies[_currentOwner]), "invalid-proxy-or-owner");
        require(proxies[_nextOwner] == UserWallet(0), "multiple-proxy-per-user-not-allowed");
        proxies[_nextOwner] = proxies[_currentOwner];
        proxies[_currentOwner] = UserWallet(0);
        emit LogRecord(_currentOwner, _nextOwner, address(proxies[_nextOwner]));
    }

}


/// @title InstaRegistry
/// @dev Initializing Registry
contract InstaRegistry is WalletRegistry {

    constructor() public {
        registry[keccak256(abi.encodePacked("admin"))] = msg.sender;
        registry[keccak256(abi.encodePacked("owner"))] = msg.sender;
    }
}
