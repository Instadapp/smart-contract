pragma solidity ^0.5.7;

interface CTokenInterface {
    function borrow(uint borrowAmount) external returns (uint);
    function borrowBalanceCurrent(address account) external returns (uint);
    function repayBorrow(uint repayAmount) external returns (uint); // For ERC20
    function totalReserves() external view returns (uint);
    function underlying() external view returns (address);

    function balanceOf(address owner) external view returns (uint256 balance);
    function allowance(address, address) external view returns (uint);
    function approve(address, uint) external;
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
}

interface ERC20Interface {
    function allowance(address, address) external view returns (uint);
    function balanceOf(address) external view returns (uint);
    function approve(address, uint) external;
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
}

interface ComptrollerInterface {
    function enterMarkets(address[] calldata cTokens) external returns (uint[] memory);
    function exitMarket(address cTokenAddress) external returns (uint);
    function getAssetsIn(address account) external view returns (address[] memory);
    function getAccountLiquidity(address account) external view returns (uint, uint, uint);
}

interface PoolInterface {
    function accessToken(address[] calldata ctknAddr, uint[] calldata tknAmt, bool isCompound) external;
    function paybackToken(address[] calldata ctknAddr, bool isCompound) external payable;
}

/** Swap Functionality */
interface ScdMcdMigration {
    function swapDaiToSai(uint daiAmt) external;
}


contract DSMath {

    function sub(uint x, uint y) internal pure returns (uint z) {
        z = x - y <= x ? x - y : 0;
    }

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
     * @dev get Compound Comptroller Address
     */
    function getCSaiAddress() public pure returns (address saiAddr) {
        // troller = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    }

    /**
     * @dev get Compound Comptroller Address
     */
    function getCDaiAddress() public pure returns (address daiAddr) {
        // troller = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    }

    /**
     * @dev get Compound Comptroller Address
     */
    function getSaiAddress() public pure returns (address saiAddr) {
        // troller = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    }

    /**
     * @dev get Compound Comptroller Address
     */
    function getDaiAddress() public pure returns (address daiAddr) {
        // troller = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    }

    /**
     * @dev get Compound Comptroller Address
     */
    function getLiquidityAddress() public pure returns (address poolAddr) {
        // poolAddr = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    }

    function enterMarket(address cErc20) internal {
        ComptrollerInterface troller = ComptrollerInterface(getComptrollerAddress());
        address[] memory markets = troller.getAssetsIn(address(this));
        bool isEntered = false;
        for (uint i = 0; i < markets.length; i++) {
            if (markets[i] == cErc20) {
                isEntered = true;
            }
        }
        if (!isEntered) {
            address[] memory toEnter = new address[](1);
            toEnter[0] = cErc20;
            troller.enterMarkets(toEnter);
        }
    }

    /**
     * @dev setting allowance to compound for the "user proxy" if required
     */
    function setApproval(address erc20, uint srcAmt, address to) internal {
        ERC20Interface erc20Contract = ERC20Interface(erc20);
        uint tokenAllowance = erc20Contract.allowance(address(this), to);
        if (srcAmt > tokenAllowance) {
            erc20Contract.approve(to, uint(-1));
        }
    }

}


contract PoolActions is Helpers {

    function accessLiquidity(uint amt) internal {
        address[] memory ctknAddrArr = new address[](1);
        ctknAddrArr[0] = getCSaiAddress();
        uint[] memory tknAmtArr = new uint[](1);
        tknAmtArr[0] = amt;
        PoolInterface(getLiquidityAddress()).accessToken(ctknAddrArr, tknAmtArr, false);
    }

    function paybackLiquidity(uint amt) internal {
        address[] memory ctknAddrArr = new address[](1);
        ctknAddrArr[0] = getCSaiAddress();
        ERC20Interface(getDaiAddress()).transfer(getLiquidityAddress(), amt);
        PoolInterface(getLiquidityAddress()).paybackToken(ctknAddrArr, false);
    }

}


/** Swap from Dai to Sai */
contract MigrationProxyActions is PoolActions {

    function swapDaiToSai(
        address scdMcdMigration,    // Migration contract address
        uint wad                            // Amount to swap
    ) internal
    {
        ERC20Interface sai = ERC20Interface(getSaiAddress());
        ERC20Interface dai = ERC20Interface(getDaiAddress());
        if (dai.allowance(address(this), scdMcdMigration) < wad) {
            dai.approve(scdMcdMigration, wad);
        }
        ScdMcdMigration(scdMcdMigration).swapDaiToSai(wad);
        sai.transfer(getLiquidityAddress(), wad);
        paybackLiquidity(wad);
    }

}


contract CompoundResolver is MigrationProxyActions {

    event LogBorrow(address erc20, address cErc20, uint tokenAmt, address owner);
    event LogRepay(address erc20, address cErc20, uint tokenAmt, address owner);

    /**
     * @dev borrow ETH/ERC20
     */
    function borrow(uint tokenAmt) internal {
        enterMarket(getCDaiAddress());
        require(CTokenInterface(getCDaiAddress()).borrow(tokenAmt) == 0, "got collateral?");
        address erc20 = CTokenInterface(getCDaiAddress()).underlying();
        ERC20Interface(erc20).transfer(getLiquidityAddress(), tokenAmt);
        emit LogBorrow(
            erc20,
            getCDaiAddress(),
            tokenAmt,
            address(this)
        );
    }

    /**
     * @dev Pay Debt ETH/ERC20
     */
    function repayToken(uint tokenAmt) internal returns (uint toRepay) {
        CTokenInterface cToken = CTokenInterface(getCSaiAddress());
        address erc20 = CTokenInterface(getCSaiAddress()).underlying();
        ERC20Interface token = ERC20Interface(erc20);
        toRepay = token.balanceOf(msg.sender);
        uint borrows = cToken.borrowBalanceCurrent(address(this));
        toRepay = toRepay > tokenAmt ? tokenAmt : toRepay;
        toRepay = toRepay > borrows ? borrows : toRepay;
        accessLiquidity(toRepay);
        setApproval(erc20, toRepay, getCSaiAddress());
        require(cToken.repayBorrow(toRepay) == 0, "Enough Tokens?");
        emit LogRepay(
            erc20,
            getCSaiAddress(),
            toRepay,
            address(this)
        );
    }
}


contract CompMigration is CompoundResolver {

    function migrate(uint debtToMigrate, address scdMcdMigration) external {
        uint initialPoolBal = sub(getLiquidityAddress().balance, 10000000000);
        uint debtPaid = repayToken(debtToMigrate);
        borrow(debtPaid);
        swapDaiToSai(scdMcdMigration, debtPaid);
        uint finalPoolBal = getLiquidityAddress().balance;
        assert(finalPoolBal >= initialPoolBal);
    }

}


contract InstaCompound is CompMigration {

    function() external payable {}

}