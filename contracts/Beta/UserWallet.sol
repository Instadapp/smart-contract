pragma solidity ^0.5.0;


/**
 * @title AddressRegistryInterface Interface 
 */
interface AddressRegistryInterface {
    function isLogic(address logicAddr) external view returns (bool);
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
        AddressRegistryInterface logicProxy = AddressRegistryInterface(registry);
        bool islogic = logicProxy.isLogic(logicAddr);
        require(islogic, "logic-not-authorised");
        _;
    }

}


/**
 * @title User Auth
 */
contract UserAuth {

    address public owner;

    /**
     * @dev Throws if not called by owner or contract itself
     */
    modifier auth {
        require(msg.sender == owner, "permission-denied");
        _;
    }
    
    /**
     * @dev sets new owner only once
     * @param _owner is the new owner of this proxy contract
     */
    function setOwner(address _owner) public auth {
        require(owner == address(0), "owner-already-assigned");
        owner = _owner;
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
contract UserWallet is AddressRecord, UserAuth, UserNote {

    event LogExecute(address target, uint src);

    /**
     * @dev sets the address registry
     */
    constructor() public {
        registry = msg.sender;
    }

    function() external payable {}

    /**
     * @dev execute authorised calls via delegate call
     * @param _target logic proxy address
     * @param _data delegate call data
     * @param _src function execution interface source
     */
    function execute(address _target, bytes memory _data, uint _src) 
        public
        payable
        note
        auth
        logicAuth(_target)
        returns (bytes memory response)
    {
        require(_target != address(0), "invalid-logic-proxy-address");
        emit LogExecute(_target, _src);
        
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