pragma solidity ^0.4.23;


contract UserAuthority {
    function canCall(address src, address dst, bytes4 sig) public view returns (bool);
}

contract UserAuthEvents {
    event LogSetAuthority (address indexed authority);
    event LogSetOwner     (address indexed owner);
}

contract UserAuth is UserAuthEvents {
    UserAuthority  public  authority;
    address      public  owner;

    constructor() public {
        owner = msg.sender;
        emit LogSetOwner(msg.sender);
    }

    function setOwner(address owner_)
        public
        auth
    {
        owner = owner_;
        emit LogSetOwner(owner);
    }

    function setAuthority(UserAuthority authority_)
        public
        auth
    {
        authority = authority_;
        emit LogSetAuthority(authority);
    }

    modifier auth {
        require(isAuthorized(msg.sender, msg.sig));
        _;
    }

    function isAuthorized(address src, bytes4 sig) internal view returns (bool) {
        if (src == address(this)) {
            return true;
        } else if (src == owner) {
            return true;
        } else if (authority == UserAuthority(0)) {
            return false;
        } else {
            return authority.canCall(src, this, sig);
        }
    }
}

contract UserNote {
    event LogNote(
        bytes4   indexed  sig,
        address  indexed  guy,
        bytes32  indexed  foo,
        bytes32  indexed  bar,
        uint              wad,
        bytes             fax
    ) anonymous;

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

interface LogicRegistry {
    function getLogic(address logicAddr) external view returns(bool);
}

contract LogicProxy {
    address public logicProxyAddr;

    function isLogic(address logicAddr) internal view returns(bool) {
        LogicRegistry logicProxy = LogicRegistry(logicProxyAddr);
        return logicProxy.getLogic(logicAddr);
    }
}

// UserProxy
// Allows code execution using a persistant identity This can be very
// useful to execute a sequence of atomic actions. Since the owner of
// the proxy can be changed, this allows for dynamic ownership models
// i.e. a multisig
contract UserProxy is UserAuth, UserNote, LogicProxy {

    constructor(address logicProxyAddr_) public {
        logicProxyAddr = logicProxyAddr_;
    }

    function() external payable {}

    function execute(address _target, bytes memory _data)
        public
        auth
        note
        payable
        returns (bytes memory response)
    {
        require(_target != address(0), "user-proxy-target-address-required");
        require(isLogic(_target), "invalid-logic-proxy-address");

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