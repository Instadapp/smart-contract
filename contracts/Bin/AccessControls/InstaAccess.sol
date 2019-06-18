pragma solidity ^0.5.2;

interface UserWalletInterface {
    function execute(
        address _target,
        bytes calldata _data,
        uint _src,
        uint _session
    ) external payable;
}

/**
 * @title InstaRegistry Interface
 */
interface RegistryInterface {
    function proxies(address owner) external view returns (address);
}


/// @title Owners
/// @notice
/// @dev
contract Owners {
    event LogAddOwner(address addr);
    event LogRemoveOwner(address addr);

    address public registry;

    /// @notice owners of the contracts
    mapping(address => bool) public owners;
    uint public ownersCount;

    /**
     * @dev Check if msg.sender is owner.
     */
    modifier onlyOwner() {
        require(isOwner(msg.sender), "permission-denied");
        _;
    }

    /// @dev Check if is owner.
    /// @param _owner (address)
    function isOwner(address _owner) public view returns (bool) {
        return owners[_owner];
    }

    /// @dev add new owner
    /// @param _owner (address)
    function addOwner(address _owner) public onlyOwner {
        owners[_owner] = true;
        ownersCount++;
    }

    /// @dev removed existing owner
    /// @param _owner (address)
    function removeOwner(address _owner) public onlyOwner {
        owners[_owner] = false;
        ownersCount--;
        require(ownersCount > 0, "zero-owner-not-allowed");
    }

}


/// @title InstaAccess
/// @dev Initializing Access Control
contract InstaAccess is Owners {

    constructor(address _registry) public {
        registry = _registry;
        owners[msg.sender] = true;
        ownersCount++;
    }

    function execute(
        address target,
        bytes memory data,
        uint src,
        uint session
    ) public payable onlyOwner
    {
        address walletAddress = RegistryInterface(registry).proxies(address(this));
        UserWalletInterface(walletAddress).execute.value(msg.value)(
            target,
            data,
            src,
            session
        );
    }

}