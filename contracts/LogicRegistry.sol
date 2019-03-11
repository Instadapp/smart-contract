pragma solidity ^0.5.0;

interface AddrRegistry {
    function getAddr(string calldata) external view returns (address);
}


contract AddressRegistry {
    address public registry;

    modifier onlyAdmin() {
        require(msg.sender == getAddress("admin"), "Permission Denied");
        _;
    }

    function getAddress(string memory name) internal view returns (address) {
        AddrRegistry addrReg = AddrRegistry(registry);
        return addrReg.getAddr(name);
    }
}


contract LogicRegistry is AddressRegistry {
    event DefaultLogicSet(address logicAddr);
    event LogicSet(address logicAddr, bool isLogic);

    mapping(address => bool) public defaultLogicProxies;
    mapping(address => bool) public logicProxies;

    constructor(address registry_) public {
        registry = registry_;
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

    function setLogic(address logicAddr, bool isLogic) public onlyAdmin {
        require(msg.sender == getAddress("admin"), "Permission Denied");
        logicProxies[logicAddr] = true;
        emit LogicSet(logicAddr, isLogic);
    }

    function setDefaultLogic(address logicAddr) public onlyAdmin {
        require(msg.sender == getAddress("admin"), "Permission Denied");
        defaultLogicProxies[logicAddr] = true;
        emit DefaultLogicSet(logicAddr);
    }

}
