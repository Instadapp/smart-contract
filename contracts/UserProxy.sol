pragma solidity ^0.5.0;


library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "math-not-safe");
        return c;
    }
}


contract UserAuth {
    using SafeMath for uint;
    using SafeMath for uint256;

    event LogSetOwner(address indexed owner, bool isGuardian);
    event LogSetGuardian(address indexed guardian);

    mapping(uint => address) public guardians;
    address public owner;
    uint public lastActivity; // timestamp
    // guardians can set owner after owner stay inactive for certain period
    uint public activePeriod; // timestamp

    constructor() public {
        owner = msg.sender;
        emit LogSetOwner(msg.sender, false);
    }

    modifier auth {
        require(isAuth(msg.sender), "permission-denied");
        _;
    }

    function setOwner(address owner_) public auth {
        owner = owner_;
        emit LogSetOwner(owner, false);
    }

    function setOwnerViaGuardian(address owner_, uint num) public {
        require(msg.sender == guardians[num], "permission-denied");
        require(block.timestamp > lastActivity.add(activePeriod), "active-period-not-over");
        owner = owner_;
        emit LogSetOwner(owner, true);
    }

    function setGuardian(uint num, address guardian_) public auth {
        require(num > 0 && num < 6, "guardians-cant-exceed-five");
        guardians[num] = guardian_;
        emit LogSetGuardian(guardian_);
    }

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


interface LogicRegistry {
    function getLogic(address logicAddr) external view returns (bool);
}


// checking if the logic proxy is authorised
contract UserLogic {
    address public logicProxyAddr;
    function isAuthorisedLogic(address logicAddr) internal view returns (bool) {
        LogicRegistry logicProxy = LogicRegistry(logicProxyAddr);
        return logicProxy.getLogic(logicAddr);
    }
}



contract UserProxy is UserAuth, UserNote, UserLogic {
    constructor(address logicProxyAddr_, uint activePeriod_) public {
        logicProxyAddr = logicProxyAddr_;
        lastActivity = block.timestamp;
        activePeriod = activePeriod_;
    }

    function() external payable {}

    function execute(address _target, bytes memory _data) public payable auth note returns (bytes memory response) {
        require(_target != address(0), "user-proxy-target-address-required");
        require(isAuthorisedLogic(_target), "logic-proxy-address-not-allowed");
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
