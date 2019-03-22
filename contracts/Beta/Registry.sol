pragma solidity ^0.5.0;

import "./UserWallet.sol";


/**
 * @title Address Registry
 */
contract AddressRegistry {
    event LogSetAddress(string name, address addr);

    mapping(bytes32 => address) registry;

    modifier isAdmin() {
        require(
            msg.sender == getAddress("admin") || 
            msg.sender == getAddress("owner"),
            "permission-denied"
        );
        _;
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
    function setAddress(string memory name, address addr) public isAdmin {
        registry[keccak256(abi.encodePacked(name))] = addr;
        emit LogSetAddress(name, addr);
    }

}


/**
 * @title Logic Registry
 */
contract LogicRegistry is AddressRegistry {

    event LogEnableLogic(address logicAddr);

    mapping(address => bool) public logicProxies;

    /**
     * @dev get the boolean of the logic contract
     * @param logicAddr is the logic proxy address
     * @return bool logic proxy is authorised by system admin
     * @return bool logic proxy is default proxy 
     */
    function isLogic(address logicAddr) public view returns (bool) {
        if (logicProxies[logicAddr]) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev enable logic proxy address which sets it to true
     * @param logicAddr is the logic proxy address
     */
    function enableLogic(address logicAddr) public isAdmin {
        logicProxies[logicAddr] = true;
        emit LogEnableLogic(logicAddr);
    }

}


/**
 * @title User Wallet Registry
 */
contract WalletRegistry is LogicRegistry {
    
    event Created(address indexed sender, address indexed owner, address proxy);
    mapping(address => UserWallet) public proxies;

    /**
     * @dev deploys a new proxy instance and sets custom owner of proxy
     * Throws if the owner already have a UserWallet
     */
    function build() public returns (UserWallet proxy) {
        require(proxies[msg.sender] == UserWallet(0), "multiple-proxy-per-user-not-allowed");
        proxy = new UserWallet();
        proxy.setOwner(msg.sender);
        emit Created(msg.sender, msg.sender, address(proxy));
        proxies[msg.sender] = proxy;
    }

}


contract InstaRegistry is WalletRegistry {

    constructor() public {
        registry[keccak256(abi.encodePacked("admin"))] = msg.sender;
        registry[keccak256(abi.encodePacked("owner"))] = msg.sender;
    }

}