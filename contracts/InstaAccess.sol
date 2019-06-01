pragma solidity ^0.5.2;


/// @title Owners
/// @notice
/// @dev
contract Owners {
    event LogAddOwner(address addr);
    event LogRemoveOwner(address addr);

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


/// @title Managers
/// @notice
/// @dev
contract Managers is Owners {
    event LogAddManager(address addr);
    event LogRemoveManager(address addr);

    /// @notice managers of the contracts
    mapping(address => bool) public managers;

    /// @dev Check if manager.
    /// @param _manager (address)
    function isManager(address _manager) public view returns (bool) {
        return managers[_manager];
    }

    /// @dev add new manager
    /// @param _manager (address)
    function addManager(address _manager) public onlyOwner {
        managers[_manager] = true;
    }

    /// @dev removed existing manager
    /// @param _manager (address)
    function removeManager(address _manager) public onlyOwner {
        managers[_manager] = false;
    }
}


/// @title Guardians
/// @notice
/// @dev
contract Guardians is Managers {
    event LogAddGuardian(address addr);
    event LogRemoveGuardian(address addr);

    /// @notice guardians of the contracts
    mapping(address => bool) public guardians;

    /// @dev Check if guardian
    /// @param _guardians (address)
    function isGuardian(address _guardians) public view returns (bool) {
        return guardians[_guardians];
    }

    /// @dev add new guardian
    /// @param _guardians (address)
    function addGuardian(address _guardians) public onlyOwner {
        guardians[_guardians] = true;
    }

    /// @dev removed existing guardian
    /// @param _guardians (address)
    function removeGuardian(address _guardians) public onlyOwner {
        guardians[_guardians] = false;
    }
}


/// @title InstaAccess
/// @dev Initializing Access Control
contract InstaAccess is Guardians {

    constructor() public {
        owners[msg.sender] = true;
        ownersCount++;
    }

}