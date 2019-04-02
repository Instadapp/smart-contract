pragma solidity ^0.5.0;


/**
 * @dev because math is not safe 
 */
library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "math-not-safe");
        return c;
    }
}


/**
 * @title AddressRegistryInterface Interface 
 */
interface AddressRegistryInterface {
    function isLogicAuth(address logicAddr) external view returns (bool, bool);
    function updateProxyRecord(address currentOwner, address nextOwner) external;
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
        AddressRegistryInterface logicProxy = AddressRegistryInterface(registry);
        (bool isLogicAuth, ) = logicProxy.isLogicAuth(logicAddr);
        require(isLogicAuth, "logic-not-authorised");
        _;
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
        setProxyRecordOwner(owner, nextOwner);
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
     * @dev execute authorised calls via delegate call
     * @param _target logic proxy address
     * @param _data delegate call data
     * @param srcNum to find the source
     * @param sessionNum to find the session
     */
    function execute(
        address _target,
        bytes memory _data,
        uint srcNum,
        uint sessionNum
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
            srcNum,
            sessionNum
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