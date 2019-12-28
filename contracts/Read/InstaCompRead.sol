pragma solidity ^0.5.8;
pragma experimental ABIEncoderV2;

interface CTokenInterface {
    function exchangeRateStored() external view returns (uint);
    function borrowRatePerBlock() external view returns (uint);
    function supplyRatePerBlock() external view returns (uint);
    function borrowBalanceStored(address) external view returns (uint);

    function balanceOf(address) external view returns (uint);
}

interface OrcaleComp {
    function getUnderlyingPrice(address) external view returns (uint);
}

interface RegistryInterface {
    function proxies(address owner) external view returns (address);
}


contract DSMath {

    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, "math-not-safe");
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, "math-not-safe");
    }

    uint constant WAD = 10 ** 18;

    function wmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }

    function wdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, WAD), y / 2) / y;
    }

}


contract Helpers is DSMath {

    /**
     * @dev get ethereum address for trade
     */
    function getAddressETH() public pure returns (address eth) {
        eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }

    /**
     * @dev get Compound Comptroller Address
     */
    function getComptrollerAddress() public pure returns (address troller) {
        troller = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    }

    /**
     * @dev get Compound Orcale Address
     */
    function getOracleAddress() public pure returns (address oracle) {
        oracle = 0x1D8aEdc9E924730DD3f9641CDb4D1B92B848b4bd;
    }

    /**
     * @dev get InstaDapp Registry Address
     */
    function getInstaRegistry() public pure returns (address addr) {
        addr = 0x498b3BfaBE9F73db90D252bCD4Fa9548Cd0Fd981;
    }

    struct CompData {
        uint tokenPrice;
        uint exchangeRateCurrent;
        uint balanceOfUser;
        uint balanceOfWallet;
        uint borrowBalanceCurrentUser;
        uint borrowBalanceCurrentWallet;
        uint supplyRatePerBlock;
        uint borrowRatePerBlock;
    }
}


contract InstaCompRead is Helpers {
    function getCompTokenData(address owner, address[] memory cAddress) public view returns (CompData[] memory) {
        address userWallet = RegistryInterface(getInstaRegistry()).proxies(owner);
        CompData[] memory tokensData = new CompData[](cAddress.length);
        for (uint i = 0; i < cAddress.length; i++) {
            CTokenInterface cToken = CTokenInterface(cAddress[i]);
            tokensData[i] = CompData(
                OrcaleComp(getOracleAddress()).getUnderlyingPrice(cAddress[i]),
                cToken.exchangeRateStored(),
                cToken.balanceOf(owner),
                cToken.balanceOf(userWallet),
                cToken.borrowBalanceStored(owner),
                cToken.borrowBalanceStored(userWallet),
                cToken.supplyRatePerBlock(),
                cToken.borrowRatePerBlock()
            );
        }
        return tokensData;
    }

    function getProxyAddress(address owner) public view returns (address proxy) {
        proxy = RegistryInterface(getInstaRegistry()).proxies(owner);
    }

    function getTokenData(address owner, address cAddress) public view returns (
        uint tokenPrice,
        uint exRate,
        uint balUser,
        uint balWallet,
        uint borrowBalUser,
        uint borrowBalWallet,
        uint supplyRate,
        uint borrowRate
    )
    {
        address userWallet = RegistryInterface(getInstaRegistry()).proxies(owner);
        tokenPrice = OrcaleComp(getOracleAddress()).getUnderlyingPrice(cAddress);
        CTokenInterface cToken = CTokenInterface(cAddress);
        exRate = cToken.exchangeRateStored();
        balUser = cToken.balanceOf(owner);
        balWallet = cToken.balanceOf(userWallet);
        borrowBalUser = cToken.borrowBalanceStored(owner);
        borrowBalWallet = cToken.borrowBalanceStored(userWallet);
        supplyRate = cToken.supplyRatePerBlock();
        borrowRate = cToken.borrowRatePerBlock();
    }
}