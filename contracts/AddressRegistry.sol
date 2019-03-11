pragma solidity ^0.5.0;


contract AddressRegistry {
    event AddressSet(string name, address addr);
    event DefaultLogicSet(address logicAddr);
    event LogicSet(address logicAddr, bool isLogic);

    mapping(bytes32 => address) registry;
    mapping(address => bool) public defaultLogicProxies;
    mapping(address => bool) public logicProxies;

    constructor() public {
        registry[keccak256(abi.encodePacked("admin"))] = msg.sender;
        registry[keccak256(abi.encodePacked("owner"))] = msg.sender;
    }

    function getAddress(string memory name) public view returns(address) {
        return registry[keccak256(abi.encodePacked(name))];
    }

    function setAddress(string memory name, address addr) public {
        require(
            msg.sender == getAddress("admin") || 
            msg.sender == getAddress("owner"),
            "Permission Denied"
        );
        registry[keccak256(abi.encodePacked(name))] = addr;
        emit AddressSet(name, addr);
    }

    modifier isAdmin() {
        require(
            msg.sender == getAddress("admin"),
            "Permission Denied"
        );
        _;
    }

    function getLogic(address logicAddr) public view returns (bool) {
        if (defaultLogicProxies[logicAddr]) {
            return true;
        } else if (logicProxies[logicAddr]) {
            return true;
        } else {
            return false;
        }
    }

    function setDefaultLogic(address logicAddr) public isAdmin {
        require(msg.sender == getAddress("admin"), "Permission Denied");
        defaultLogicProxies[logicAddr] = true;
        emit DefaultLogicSet(logicAddr);
    }

    function setLogic(address logicAddr, bool isLogic) public isAdmin {
        require(msg.sender == getAddress("admin"), "Permission Denied");
        logicProxies[logicAddr] = true;
        emit LogicSet(logicAddr, isLogic);
    }

}