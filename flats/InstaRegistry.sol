
// File: openzeppelin-solidity/contracts/math/SafeMath.sol

pragma solidity ^0.5.2;

/**
 * @title SafeMath
 * @dev Unsigned math operations with safety checks that revert on error
 */
library SafeMath {
    /**
     * @dev Multiplies two unsigned integers, reverts on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
     * @dev Integer division of two unsigned integers truncating the quotient, reverts on division by zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Subtracts two unsigned integers, reverts on overflow (i.e. if subtrahend is greater than minuend).
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Adds two unsigned integers, reverts on overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
     * @dev Divides two unsigned integers and returns the remainder (unsigned integer modulo),
     * reverts when dividing by zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

// File: contracts/UserWallet.sol

pragma solidity ^0.5.2;


/**
 * @title RegistryInterface Interface 
 */
interface RegistryInterface {
    function logic(address logicAddr) external view returns (bool);
    function record(address currentOwner, address nextOwner) external;
}

/**
 * @title Address Registry Record
 */
contract AddressRecord {

    /**
     * @dev address registry of system, logic and wallet addresses
     */
    address public registry;

    /**
     * @dev Throws if the logic is not authorised
     */
    modifier logicAuth(address logicAddr) {
        require(logicAddr != address(0), "logic-proxy-address-required");
        bool islogic = RegistryInterface(registry).logic(logicAddr);
        require(islogic, "logic-not-authorised");
        _;
    }

}


/**
 * @title User Auth
 */
contract UserAuth is AddressRecord {
    using SafeMath for uint;
    using SafeMath for uint256;

    event LogSetOwner(address indexed owner);
    address public owner;

    /**
     * @dev Throws if not called by owner or contract itself
     */
    modifier auth {
        require(isAuth(msg.sender), "permission-denied");
        _;
    }

    /**
     * @dev sets new owner
     */
    function setOwner(address nextOwner) public auth {
        RegistryInterface(registry).record(owner, nextOwner);
        owner = nextOwner;
        emit LogSetOwner(nextOwner);
    }

    /**
     * @dev checks if called by owner or contract itself
     * @param src is the address initiating the call
     */
    function isAuth(address src) public view returns (bool) {
        if (src == owner) {
            return true;
        } else if (src == address(this)) {
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


/**
 * @title User Owned Contract Wallet
 */
contract UserWallet is UserAuth, UserNote {

    event LogExecute(address sender, address target, uint srcNum, uint sessionNum);

    /**
     * @dev sets the "address registry", owner's last activity, owner's active period and initial owner
     */
    constructor() public {
        registry = msg.sender;
        owner = msg.sender;
    }

    function() external payable {}

    /**
     * @dev Execute authorised calls via delegate call
     * @param _target logic proxy address
     * @param _data delegate call data
     * @param _srcNum to find the source
     * @param _sessionNum to find the session
     */
    function execute(
        address _target,
        bytes memory _data,
        uint _srcNum,
        uint _sessionNum
    ) 
        public
        payable
        note
        auth
        logicAuth(_target)
        returns (bytes memory response)
    {
        emit LogExecute(
            msg.sender,
            _target,
            _srcNum,
            _sessionNum
        );
        
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

// File: contracts/InstaRegistry.sol

pragma solidity ^0.5.2;



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

    event LogEnableDefaultLogic(address logicAddress);
    event LogEnableLogic(address logicAddress);
    event LogDisableLogic(address logicAddress);

    /// @notice Map of default proxy state
    mapping(address => bool) public defaultLogicProxies;
    
    /// @notice Map of logic proxy state
    mapping(address => bool) public logicProxies;

    /// @dev 
    /// @param _logicAddress (address)
    /// @return  (bool)
    function logic(address _logicAddress) public view returns (bool) {
        if (defaultLogicProxies[_logicAddress] || logicProxies[_logicAddress]) {
            return true;
        } else {
            return false;
        }
    }

    /// @dev Sets the default logic proxy to true
    /// default proxies mostly contains the logic for withdrawal of assets
    /// and can never be false to freely let user withdraw their assets
    /// @param _logicAddress (address)
    function enableDefaultLogic(address _logicAddress) public isAdmin {
        defaultLogicProxies[_logicAddress] = true;
        emit LogEnableDefaultLogic(_logicAddress);
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
    function build(address owner) public returns (UserWallet proxy) {
        require(proxies[owner] == UserWallet(0), "multiple-proxy-per-user-not-allowed");
        proxy = new UserWallet();
        proxies[address(this)] = proxy; // will be changed via record() in next line execution
        proxy.setOwner(owner);
        emit Created(msg.sender, owner, address(proxy));
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
