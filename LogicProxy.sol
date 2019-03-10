pragma solidity ^0.4.23;


interface AddrRegistry {
    function getAddr(string calldata name) external view returns(address);
}

contract AddressRegistry {
    address public registry;

    modifier onlyAdmin() {
        require(
            msg.sender == getAddress("admin"),
            "Permission Denied"
        );
        _;
    }

    function getAddress(string memory name) internal view returns(address) {
        AddrRegistry addrReg = AddrRegistry(registry);
        return addrReg.getAddr(name);
    }
}

contract LogicProxyRegistry is AddressRegistry {

    event DefaultLogicSet(address logicAddr);
    event LogicSet(address logicAddr, bool isLogic);

    mapping(address => bool) public DefaultLogicProxies;
    mapping(address => bool) public LogicProxies;

    constructor(address registry_) public {
        registry = registry_;
    }

    function getLogic(address logicAddr) public view returns(bool) {
        if (DefaultLogicProxies[logicAddr]) {
            return true;
        } else if (LogicProxies[logicAddr]) {
            return true;
        } else {
            return false;
        }
    }

    function setLogic(address logicAddr, bool isLogic) public onlyAdmin {
        require(msg.sender == getAddress("admin"), "Permission Denied");
        LogicProxies[logicAddr] = true;
        emit LogicSet(logicAddr, isLogic);
    }

    function setDefaultLogic(address logicAddr) public onlyAdmin {
        require(msg.sender == getAddress("admin"), "Permission Denied");
        DefaultLogicProxies[logicAddr] = true;
        emit DefaultLogicSet(logicAddr);
    }

}