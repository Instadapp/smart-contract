pragma solidity ^0.5.0;


contract AddressRegistry {
    event LogSetAddress(string name, address addr);
    event LogSetDefaultLogic(address logicAddr);
    event LogSetLogic(address logicAddr, bool isLogic);

    mapping(bytes32 => address) registry;
    mapping(address => bool) public defaultLogicProxies;
    mapping(address => bool) public logicProxies;

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