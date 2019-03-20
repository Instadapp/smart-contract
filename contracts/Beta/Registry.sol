pragma solidity ^0.5.0;

import "./UserWallet.sol";


/**
 * @title User Wallet Registry
 */
contract WalletRegistry {
    
    event Created(address indexed sender, address indexed owner, address proxy);
    mapping(address => UserWallet) public proxies;

    /**
     * @dev deploys a new proxy instance and sets custom owner of proxy
     * Throws if the owner already have a UserWallet
     */
    function build() public returns (UserWallet proxy) {
        require(proxies[msg.sender] == UserWallet(0), "multiple-proxy-per-user-not-allowed");
        proxy = new UserWallet();
        proxy.setOwner(msg.sender);
        emit Created(msg.sender, msg.sender, address(proxy));
        proxies[msg.sender] = proxy;
    }

}