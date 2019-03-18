pragma solidity ^0.5.0;


library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "math-not-safe");
        return c;
    }
}

/**
 * @title ProxyRegistry Interface 
 */
interface ProxyRegistryInterface {
    function updateProxyRecord(address currentOwner, address nextOwner) external;
    function guardianEnabled() external returns (bool);
}

/**
 * @title AddressRegistryInterface Interface 
 */
interface AddressRegistryInterface {
    function getLogic(address logicAddr) external view returns (bool);
    function getAddress(string calldata name) external view returns(address);
}


/**
 * @title Proxy Record
 */
contract ProxyRecord {
    
    address public proxyContract;
    
    /**
     * @dev this updates the internal proxy ownership on "proxy registry" contract
     * @param currentOwner is the current owner
     * @param nextOwner is the new assigned owner
     */
    function setProxyRecordOwner(address currentOwner, address nextOwner) internal {
        ProxyRegistryInterface initCall = ProxyRegistryInterface(proxyContract);
        initCall.updateProxyRecord(currentOwner, nextOwner);
    }

}

/**
 * @title User Auth
 */
contract UserAuth is ProxyRecord {
    using SafeMath for uint;
    using SafeMath for uint256;

    event LogSetOwner(address indexed owner, address setter);
    event LogSetPendingOwner(address indexed pendingOwner, address setter);
    address public owner;
    address public pendingOwner;
    uint public claimOnwershipTime; // 7 days

    /**
     * @dev defines the "proxy registry" contract and sets the owner
     */
    constructor() public {
        proxyContract = msg.sender;
        owner = msg.sender;
        emit LogSetOwner(owner, msg.sender);
    }

    /**
     * @dev Throws if not called by owner or contract itself
     */
    modifier auth {
        require(isAuth(msg.sender), "permission-denied");
        _;
    }

    /**
     * @dev sets the "pending owner"
     * @param nextOwner is the assigned "pending owner"
     */
    function setPendingOwner(address nextOwner) public auth {
        require(block.timestamp > claimOnwershipTime, "owner-is-still-pending");
        pendingOwner = nextOwner;
        claimOnwershipTime = block.timestamp.add(7 days);
        emit LogSetPendingOwner(nextOwner, msg.sender);
    }

    /**
     * @dev sets "pending owner" as real owner
     * Throws if called before 7 day after assigning "pending owner"
     */
    function setOwner() public {
        require(pendingOwner != address(0), "no-pending-address");
        setProxyRecordOwner(owner, pendingOwner);
        owner = pendingOwner;
        pendingOwner = address(0);
        emit LogSetOwner(owner, msg.sender);
    }

    /**
     * @dev checks if called by owner or contract itself
     * @param src is the address initiating the call
     */
    function isAuth(address src) internal view returns (bool) {
        if (src == address(this)) {
            return true;
        } else if (src == owner) {
            return true;
        } else {
            return false;
        }
    }

}

/**
 * @title User Guardians
 */
contract UserGuardian is UserAuth {

    event LogSetGuardian(address indexed guardian);
    event LogNewActivePeriod(uint newActivePeriod);
    event LogSetOwnerViaGuardian(address nextOwner, address indexed guardian);

    mapping(uint => address) public guardians;
    uint public lastActivity; // time when called "execute" last time
    uint public activePeriod; // the period over lastActivity when guardians have no rights

    /**
     * @dev Throws if guardians not enabled by system admin
     */
    modifier guard() {
        ProxyRegistryInterface initCall = ProxyRegistryInterface(proxyContract);
        require(initCall.guardianEnabled());
        _;
    }

    /**
     * @dev guardians can set "owner" after owner stay inactive for minimum "activePeriod"
     * @param nextOwner is the new owner
     * @param num is the assigned guardian number
     */
    function setOwnerViaGuardian(address nextOwner, uint num) public guard {
        require(msg.sender == guardians[num], "permission-denied");
        require(block.timestamp > lastActivity.add(activePeriod), "active-period-not-over");
        owner = nextOwner;
        emit LogSetOwnerViaGuardian(nextOwner, guardians[num]);
    }

    /**
     * @dev sets the guardian with assigned number (upto 3)
     * @param num is the guardian assigned number
     * @param _guardian is the new guardian address
     */
    function setGuardian(uint num, address _guardian) public auth guard {
        require(num > 0 && num < 4, "guardians-cant-exceed-three");
        guardians[num] = _guardian;
        emit LogSetGuardian(_guardian);
    }

    /**
     * @dev sets the guardian with assigned number (upto 3)
     * @param num is the guardian assigned number
     * @param _guardian is the new guardian address
     */
    function updateActivePeriod(uint _activePeriod) public auth guard {
        activePeriod = _activePeriod;
        emit LogNewActivePeriod(_activePeriod);
    }

}

/**
 * @dev logging the execute events
 */
contract UserNote {
    event LogNote(
        bytes4 indexed sig,
        address indexed guy,
        bytes32 indexed foo,
        bytes32 bar,
        uint wad,
        bytes fax
    );

    modifier note {
        bytes32 foo;
        bytes32 bar;
        assembly {
            foo := calldataload(4)
            bar := calldataload(36)
        }
        emit LogNote(
            msg.sig, 
            msg.sender, 
            foo, 
            bar, 
            msg.value, 
            msg.data
        );
        _;
    }
}


// checking if the logic proxy is authorised
contract UserLogic {
    address public logicProxyAddr;
    function isLogicAuthorised(address logicAddr) internal view returns (bool) {
        AddressRegistryInterface logicProxy = AddressRegistryInterface(logicProxyAddr);
        return logicProxy.getLogic(logicAddr);
    }
}


contract UserProxy is UserGuardian, UserNote, UserLogic {

    constructor(address _owner, address _logicProxyAddr) public {
        logicProxyAddr = _logicProxyAddr;
        lastActivity = block.timestamp;
        activePeriod = 30 days; // default and changeable
        owner = _owner;
    }

    function() external payable {}

    function execute(address _target, bytes memory _data) public payable auth note returns (bytes memory response) {
        require(_target != address(0), "user-proxy-target-address-required");
        require(isLogicAuthorised(_target), "logic-proxy-address-not-allowed");
        lastActivity = block.timestamp;
        // call contract in current context
        assembly {
            let succeeded := delegatecall(sub(gas, 5000), _target, add(_data, 0x20), mload(_data), 0, 0)
            let size := returndatasize

            response := mload(0x40)
            mstore(0x40, add(response, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            mstore(response, size)
            returndatacopy(add(response, 0x20), 0, size)

            switch iszero(succeeded)
                case 1 {
                    // throw if delegatecall failed
                    revert(add(response, 0x20), size)
                }
        }
    }

}
