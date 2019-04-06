// This Auth Model also includes UserWallet Logics
// TODO => make it single Auth code for future launch where this Auth Contract will be the owner of UserWallet

pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
 * @title AddressRegistryInterface Interface 
 */
interface AddressRegistryInterface {
    function isLogicAuth(address logicAddr) external view returns (bool, bool);
    function updateProxyRecord(address currentOwner, address nextOwner) external;
    function guardianEnabled() external view returns (bool);
    function managerEnabled() external view returns (bool);
}

/**
 * @title UserWallet Interface
 */
// interface UserWalletInterface {
// get the wallet address based on the owner of this wallet
// and use execute interface from main UserWallet to call execute on this contract
// }


/**
 * @title Address Registry Record
 */
contract AddressRecord {
    /**
     * @dev address registry of system, logic and wallet addresses
     */
    address public registry;

    /**
     * @param logicAddr is the logic proxy contract address
     * @return the true boolean for logic proxy if authorised otherwise false
     */
    function isLogicAuthorised(address logicAddr) public view returns (bool, bool) {
        AddressRegistryInterface logicProxy = AddressRegistryInterface(registry);
        (bool isLogic, bool isDefault) = logicProxy.isLogicAuth(logicAddr);
        return (isLogic, isDefault);
    }

    /**
     * @dev this updates the internal proxy ownership on "registry" contract
     * @param currentOwner is the current owner
     * @param nextOwner is the new assigned owner
     */
    function setProxyRecordOwner(address currentOwner, address nextOwner) internal {
        AddressRegistryInterface initCall = AddressRegistryInterface(registry);
        initCall.updateProxyRecord(currentOwner, nextOwner);
    }

}


/**
 * @title User Auth
 */
contract UserAuth is AddressRecord {
    using SafeMath for uint;
    using SafeMath for uint256;

    event LogSetOwner(address indexed owner, address setter);
    event LogSetPendingOwner(address indexed pendingOwner, address setter);
    address public owner;
    address public pendingOwner;
    uint public claimOnwershipTime; // now + 7 days
    uint public gracePeriod; // to set the new owner - defaults to 3 days

    /**
     * @dev defines the "proxy registry" contract and sets the owner
     */
    constructor() public {
        gracePeriod = 3 days;
    }

    /**
     * @dev Throws if not called by owner or contract itself
     */
    modifier auth {
        require(isAuth(msg.sender), "permission-denied");
        _;
    }

    /**
     * @dev sets the "pending owner" and provide 3 days grace period to set the new owner via setOwner()
     * Throws if called before 10 (i.e. 7 + 3) day after assigning "pending owner"
     * @param nextOwner is the assigned "pending owner"
     */
    function setPendingOwner(address nextOwner) public auth {
        require(block.timestamp > claimOnwershipTime.add(gracePeriod), "owner-is-still-pending");
        pendingOwner = nextOwner;
        claimOnwershipTime = block.timestamp.add(7 days);
        emit LogSetPendingOwner(nextOwner, msg.sender);
    }

    /**
     * @dev sets "pending owner" as real owner
     * Throws if no "pending owner"
     * Throws if called before 7 day after assigning "pending owner"
     */
    function setOwner() public {
        require(pendingOwner != address(0), "no-pending-address");
        require(block.timestamp > claimOnwershipTime, "owner-is-still-pending");
        setProxyRecordOwner(owner, pendingOwner);
        owner = pendingOwner;
        pendingOwner = address(0);
        emit LogSetOwner(owner, msg.sender);
    }

    /**
     * @dev sets owner and function is only be called once by registry on build()
     * and this hack verifiy the contract on etherscan automatically
     * as no dynamic owner address is sent in the constructor
     * @param _owner is the new owner of this contract wallet
     */
    function setOwnerOnce(address _owner) public auth {
        require(msg.sender == registry, "permission-denied");
        owner = _owner;
        emit LogSetOwner(owner, msg.sender);
    }

    /**
     * @dev checks if called by owner or contract itself
     * @param src is the address initiating the call
     */
    function isAuth(address src) public view returns (bool) {
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
 * @dev the assigned guardian addresses (upto 3) can set new owners
 * but only after certain period of owner's inactivity (i.e. activePeriod)
 */
contract UserGuardian is UserAuth {
    event LogSetGuardian(uint num, address indexed prevGuardian, address indexed newGuardian);
    event LogNewActivePeriod(uint newActivePeriod);
    event LogSetOwnerViaGuardian(address nextOwner, address indexed guardian);

    mapping(uint => address) public guardians;
    uint public lastActivity; // time when called "execute" last time
    uint public activePeriod; // the period over lastActivity when guardians have no rights

    /**
     * @dev Throws if guardians not enabled by system admin
     */
    modifier isGuardianEnabled() {
        AddressRegistryInterface initCall = AddressRegistryInterface(registry);
        require(initCall.guardianEnabled(), "guardian-not-enabled");
        _;
    }

    /**
     * @dev guardians can set "owner" after owner stay inactive for minimum "activePeriod"
     * @param nextOwner is the new owner
     * @param num is the assigned guardian number
     */
    function setOwnerViaGuardian(address nextOwner, uint num) public isGuardianEnabled {
        require(isGuardian(msg.sender), "not-guardian");
        require(msg.sender == guardians[num], "permission-denied");
        require(block.timestamp > lastActivity.add(activePeriod), "active-period-not-over");
        owner = nextOwner;
        emit LogSetOwnerViaGuardian(nextOwner, guardians[num]);
    }

    /**
     * @dev sets the guardian with assigned number (upto 5)
     * @param num is the guardian assigned number
     * @param _guardian is the new guardian address
     */
    function setGuardian(uint num, address _guardian) public auth isGuardianEnabled {
        require(num > 0 && num < 6, "guardians-cant-exceed-three");
        emit LogSetGuardian(num, guardians[num], _guardian);
        guardians[num] = _guardian;
    }

    /**
     * @dev sets the guardian with assigned number (upto 5)
     * @param _activePeriod is the period when guardians have no rights to dethrone the owner
     */
    function updateActivePeriod(uint _activePeriod) public auth isGuardianEnabled {
        activePeriod = _activePeriod;
        emit LogNewActivePeriod(_activePeriod);
    }

    /**
     * @dev Throws if the msg.sender is not guardian
     */
    function isGuardian(address _guardian) public view returns (bool) {
        if (_guardian == guardians[1] || _guardian == guardians[2] || _guardian == guardians[3] || _guardian == guardians[4] || _guardian == guardians[5]) {
            return true;
        } else {
            return false;
        }
    }

}

/**
 * @title User Manager
 * @dev the assigned manager addresses (upto 3) can manage the wealth in contract to contract fashion
 * but can't withdraw the assets on their personal address
 */
contract UserManager is UserGuardian {
    event LogSetManager(uint num, address indexed prevManager, address indexed newManager);

    mapping(uint => address) public managers;

    /**
     * @dev Throws if manager not enabled by system admin
     */
    modifier isManagerEnabled() {
        AddressRegistryInterface initCall = AddressRegistryInterface(registry);
        require(initCall.managerEnabled(), "admin-not-enabled");
        _;
    }

    /**
     * @dev sets the manager with assigned number (upto 5)
     * @param num is the assigned number of manager
     * @param _manager is the new admin address
     */
    function setManager(uint num, address _manager) public auth isManagerEnabled {
        require(num > 0 && num < 6, "guardians-cant-exceed-three");
        emit LogSetManager(num, managers[num], _manager);
        managers[num] = _manager;
    }

    /**
     * @dev Throws if the msg.sender is not manager
     */
    function isManager(address _manager) public view returns (bool) {
        if (_manager == managers[1] || _manager == managers[2] || _manager == managers[3] || _manager == managers[4] || _manager == managers[5]) {
            return true;
        } else {
            return false;
        }
    }

}

/**
 * @dev logging the execute events
 */
contract UserNote {
    event LogNote(bytes4 indexed sig, address indexed guy, bytes32 indexed foo, bytes32 bar, uint wad, bytes fax);

    modifier note {
        bytes32 foo;
        bytes32 bar;
        assembly {
            foo := calldataload(4)
            bar := calldataload(36)
        }
        emit LogNote(msg.sig, msg.sender, foo, bar, msg.value, msg.data);
        _;
    }
}

/**
 * @title User Owned Contract Wallet
 */
contract InstaWallet is UserManager, UserNote {
    event LogExecute(address sender, address target, uint srcNum, uint sessionNum);

    /**
     * @dev sets the "address registry", owner's last activity, owner's active period and initial owner
     */
    constructor() public {
        registry = msg.sender;
        owner = msg.sender; // will be changed in initial call itself
        lastActivity = block.timestamp;
        activePeriod = 30 days; // default on deployment and changeable afterwards
    }

    function() external payable {}

    /**
     * @dev execute authorised calls via delegate call
     * @param _target logic proxy address
     * @param _data delegate call data
     * @param srcNum to find the source
     * @param sessionNum to find the session
     */
    function execute(address _target, bytes memory _data, uint srcNum, uint sessionNum)
        public
        payable
        note
        isExecutable(_target)
        returns (bytes memory response)
    {
        lastActivity = block.timestamp;
        emit LogExecute(msg.sender, _target, srcNum, sessionNum);

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

    /**
     * @dev checks if the proxy is authorised
     * and if the sender is owner or contract itself or manager
     * and if manager then Throws if target is default proxy address
     */
    modifier isExecutable(address proxyTarget) {
        require(proxyTarget != address(0), "logic-proxy-address-required");

        (bool isLogic, bool isDefault) = isLogicAuthorised(proxyTarget);
        require(isLogic, "logic-proxy-address-not-allowed");

        bool enact = false;
        if (isAuth(msg.sender)) {
            enact = true;
        } else if (isManager(msg.sender) && !isDefault) {
            enact = true;
        }

        require(enact, "not-executable");
        _;
    }

}
