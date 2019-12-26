pragma solidity 0.5.11;

interface ManagerLike {
    function give(uint, address) external;
}

interface InstaMcdAddress {
    function manager() external returns (address);
}


contract Common {
    /**
     * @dev get MakerDAO MCD Address contract
     */
    function getMcdAddresses() public pure returns (address mcd) {
        mcd = 0xF23196DF1C440345DE07feFbe556a5eF0dcD29F0;
    }

}


contract InstaMcdGive is Common {
    function transferOwner(uint vault) public {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        ManagerLike(manager).give(vault, msg.sender);
    }
}