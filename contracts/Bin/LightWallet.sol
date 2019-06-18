pragma solidity ^0.5.2;


/**
 * @title User Auth
 */
contract UserAuth {

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
        require(nextOwner != address(0x0), "invalid-address");
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
        }
        return false;
    }
}


/**
 * @title User Owned Contract Wallet
 */
contract UserWallet is UserAuth {

    event LogExecute(address target, uint sessionID);

    constructor() public {
        owner = msg.sender;
    }

    function() external payable {}

    /**
     * @dev Execute authorised calls via delegate call
     * @param _target logic proxy address
     * @param _data delegate call data
     * @param _session to find the session
     */
    function execute(
        address _target,
        bytes memory _data,
        uint _session
    )
        public
        payable
        auth
        returns (bytes memory response)
    {
        emit LogExecute(_target, _session);

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