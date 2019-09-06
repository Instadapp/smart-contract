pragma solidity ^0.5.7;

interface CTokenInterface {
    function redeemUnderlying(uint redeemAmount) external returns (uint);
    function borrow(uint borrowAmount) external returns (uint);
    function exchangeRateCurrent() external returns (uint);
    function borrowBalanceCurrent(address account) external returns (uint);

    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256 balance);
    function allowance(address, address) external view returns (uint);
    function approve(address, uint) external;
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
}

interface CERC20Interface {
    function mint(uint mintAmount) external returns (uint); // For ERC20
    function repayBorrow(uint repayAmount) external returns (uint); // For ERC20
    function borrowBalanceCurrent(address account) external returns (uint);
}

interface CETHInterface {
    function mint() external payable; // For ETH
    function repayBorrow() external payable; // For ETH
    function borrowBalanceCurrent(address account) external returns (uint);
}

interface ERC20Interface {
    function allowance(address, address) external view returns (uint);
    function balanceOf(address) external view returns (uint);
    function approve(address, uint) external;
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
    function deposit() external payable;
    function withdraw(uint) external;
}

interface ComptrollerInterface {
    function enterMarkets(address[] calldata cTokens) external returns (uint[] memory);
    function getAssetsIn(address account) external view returns (address[] memory);
    function getAccountLiquidity(address account) external view returns (uint, uint, uint);
}

interface CompOracleInterface {
    function getUnderlyingPrice(address) external view returns (uint);
}

interface KyberInterface {
    function trade(
        address src,
        uint srcAmount,
        address dest,
        address destAddress,
        uint maxDestAmount,
        uint minConversionRate,
        address walletId
        ) external payable returns (uint);
}


contract DSMath {

    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, "math-not-safe");
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        z = x - y <= x ? x - y : 0;
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
     * @dev get ethereum address for trade
     */
    function getAddressWETH() public pure returns (address eth) {
        eth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    }

    /**
     * @dev get ethereum address for trade
     */
    function getAddressUSDC() public pure returns (address usdc) {
        usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    }

    /**
     * @dev get ethereum address for trade
     */
    function getAddressZRXExchange() public pure returns (address zrxExchange) {
        zrxExchange = 0x080bf510FCbF18b91105470639e9561022937712;
    }

    function getAddressZRXERC20() public pure returns (address zrxerc20) {
        zrxerc20 = 0x95E6F48254609A6ee006F7D493c8e5fB97094ceF;
    }

    /**
     * @dev get ethereum address for trade
     */
    function getAddressKyberProxy() public pure returns (address kyberProxy) {
        kyberProxy = 0x818E6FECD516Ecc3849DAf6845e3EC868087B755;
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
    function getCompOracleAddress() public pure returns (address troller) {
        troller = 0xe7664229833AE4Abf4E269b8F23a86B657E2338D;
    }

    /**
     * @dev get Compound Comptroller Address
     */
    function getCETHAddress() public pure returns (address cEth) {
        cEth = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
    }

    /**
     * @dev get Compound Comptroller Address
     */
    function getCUSDCAddress() public pure returns (address cUsdc) {
        cUsdc = 0x39AA39c021dfbaE8faC545936693aC917d5E7563;
    }

    /**
     * @dev get Compound Comptroller Address
     */
    function getAddressAdmin() public pure returns (address admin) {
        admin = 0xa7615CD307F323172331865181DC8b80a2834324;
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
            erc20Contract.approve(to, 2**255);
        }
    }

}


contract CompoundHelper is Helpers {

    /**
     * @dev get users overall details for Compound
     */
    function getCompStats(
        address user,
        address[] memory cTokenAddr,
        uint[] memory cTokenFactor
    ) public returns (uint totalSupply, uint totalBorrow, uint maxBorrow, uint borrowRemain, uint maxWithdraw, uint ratio)
    {
        for (uint i = 0; i < cTokenAddr.length; i++) {
            address cTokenAdd = cTokenAddr[i];
            uint factor = cTokenFactor[i];
            (uint supplyInEth, uint borrowInEth) = compSupplyBorrow(cTokenAdd, user);
            totalSupply += supplyInEth;
            totalBorrow += borrowInEth;
            maxBorrow += wmul(supplyInEth, factor);
        }
        borrowRemain = sub(maxBorrow, totalBorrow);
        maxWithdraw = sub(wdiv(borrowRemain, 750000000000000000), 10); // divide it by 0.75 (ETH Factor)
        uint userEthSupply = getEthSupply(user);
        maxWithdraw = userEthSupply > maxWithdraw ? maxWithdraw : userEthSupply;
        ratio = wdiv(totalBorrow, totalSupply);
    }

    /**
     * @dev get user's token supply and borrow in ETH
     */
    function compSupplyBorrow(address cTokenAdd, address user) internal returns(uint supplyInEth, uint borrowInEth) {
        CTokenInterface cTokenContract = CTokenInterface(cTokenAdd);
        uint tokenPriceInEth = CompOracleInterface(getCompOracleAddress()).getUnderlyingPrice(cTokenAdd);
        uint cTokenBal = sub(cTokenContract.balanceOf(user), 1);
        uint cTokenExchangeRate = cTokenContract.exchangeRateCurrent();
        uint tokenSupply = sub(wmul(cTokenBal, cTokenExchangeRate), 1);
        supplyInEth = sub(wmul(tokenSupply, tokenPriceInEth), 10);
        uint tokenBorrowed = cTokenContract.borrowBalanceCurrent(user);
        borrowInEth = add(wmul(tokenBorrowed, tokenPriceInEth), 10);
    }

    function getEthSupply(address user) internal returns (uint ethSupply) {
        CTokenInterface cTokenContract = CTokenInterface(getCETHAddress());
        uint cTokenBal = sub(cTokenContract.balanceOf(user), 1);
        uint cTokenExchangeRate = cTokenContract.exchangeRateCurrent();
        ethSupply = wmul(cTokenBal, cTokenExchangeRate);
    }

    function usdcBorrowed(address user) internal returns (uint usdcAmt) {
        CTokenInterface cTokenContract = CTokenInterface(getCUSDCAddress());
        usdcAmt = cTokenContract.borrowBalanceCurrent(user);
    }

    function getUsdcRemainBorrow(uint usdcInEth) internal view returns (uint usdcAmt) {
        uint tokenPriceInEth = CompOracleInterface(getCompOracleAddress()).getUnderlyingPrice(getCUSDCAddress());
        usdcAmt = sub(wdiv(usdcInEth, tokenPriceInEth), 10);
    }

}


contract CompoundResolver is CompoundHelper {

    event LogMint(address erc20, address cErc20, uint tokenAmt, address owner);
    event LogRedeem(address erc20, address cErc20, uint tokenAmt, address owner);
    event LogBorrow(address erc20, address cErc20, uint tokenAmt, address owner);
    event LogRepay(address erc20, address cErc20, uint tokenAmt, address owner);

    /**
     * @dev Deposit ETH/ERC20 and mint Compound Tokens
     */
    function mintCEth(uint tokenAmt) internal {
        CETHInterface cToken = CETHInterface(getCETHAddress());
        cToken.mint.value(tokenAmt)();
        emit LogMint(
            getAddressETH(),
            getCETHAddress(),
            tokenAmt,
            msg.sender
        );
    }

    /**
     * @dev Redeem ETH/ERC20 and mint Compound Tokens
     * @param tokenAmt Amount of token To Redeem
     */
    function redeemEth(uint tokenAmt) internal {
        CTokenInterface cToken = CTokenInterface(getCETHAddress());
        setApproval(getCETHAddress(), 10**30, getCETHAddress());
        require(cToken.redeemUnderlying(tokenAmt) == 0, "something went wrong");
        emit LogRedeem(
            getAddressETH(),
            getCETHAddress(),
            tokenAmt,
            address(this)
        );
    }

    /**
     * @dev borrow ETH/ERC20
     */
    function borrow(uint tokenAmt) internal {
        require(CTokenInterface(getCUSDCAddress()).borrow(tokenAmt) == 0, "got collateral?");
        emit LogBorrow(
            getAddressUSDC(),
            getCUSDCAddress(),
            tokenAmt,
            address(this)
        );
    }

    /**
     * @dev Pay Debt ETH/ERC20
     */
    function repayUsdc(uint tokenAmt) internal {
        CERC20Interface cToken = CERC20Interface(getCUSDCAddress());
        setApproval(getAddressUSDC(), tokenAmt, getCUSDCAddress());
        require(cToken.repayBorrow(tokenAmt) == 0, "transfer approved?");
        emit LogRepay(
            getAddressUSDC(),
            getCUSDCAddress(),
            tokenAmt,
            address(this)
        );
    }

}


contract CompoundSave is CompoundResolver {

    event LogSaveCompoundUsdc(uint srcETH, uint destDAI);

    event LogLeverageCompoundUsdc(uint srcDAI,uint destETH);

    function save(
        uint ethToFree,
        uint zrxEthAmt,
        bool isKyber,
        bytes memory calldataHexString,
        address[] memory ctokenAddr,
        uint[] memory ctokenFactor
    ) public
    {
        enterMarket(getCETHAddress());
        enterMarket(getCUSDCAddress());
        (,,,,uint maxWithdraw,) = getCompStats(address(this), ctokenAddr, ctokenFactor);
        uint ethToSwap = ethToFree < maxWithdraw ? ethToFree : maxWithdraw;
        redeemEth(ethToSwap);
        ERC20Interface wethContract = ERC20Interface(getAddressWETH());
        wethContract.deposit.value(zrxEthAmt)();
        wethContract.approve(getAddressZRXERC20(), zrxEthAmt);
        (bool swapSuccess,) = getAddressZRXExchange().call(calldataHexString);
        assert(swapSuccess);
        uint remainEth = sub(ethToSwap, zrxEthAmt);
        if (remainEth > 0 && isKyber) {
            KyberInterface(getAddressKyberProxy()).trade.value(remainEth)(
                    getAddressETH(),
                    remainEth,
                    getAddressUSDC(),
                    address(this),
                    2**255,
                    0,
                    getAddressAdmin()
                );
        }
        ERC20Interface usdcContract = ERC20Interface(getAddressUSDC());
        uint usdcBal = usdcContract.balanceOf(address(this));
        repayUsdc(usdcBal);
        emit LogSaveCompoundUsdc(ethToSwap, usdcBal);
    }

    function leverage(
        uint usdcToBorrow,
        uint zrxUsdcAmt,
        bytes memory calldataHexString,
        bool isKyber,
        address[] memory cTokenAddr,
        uint[] memory ctokenFactor
    ) public
    {
        enterMarket(getCETHAddress());
        enterMarket(getCUSDCAddress());
        (,,,uint borrowRemain,,) = getCompStats(address(this), cTokenAddr, ctokenFactor);
        uint usdcToSwap = getUsdcRemainBorrow(borrowRemain);
        usdcToSwap = usdcToSwap < usdcToBorrow ? usdcToSwap : usdcToBorrow;
        borrow(usdcToSwap);
        ERC20Interface usdcContract = ERC20Interface(getAddressUSDC());
        usdcContract.approve(getAddressZRXERC20(), zrxUsdcAmt);
        (bool swapSuccess,) = getAddressZRXExchange().call(calldataHexString);
        assert(swapSuccess);
        uint usdcRemain = sub(usdcToSwap, zrxUsdcAmt);
        if (usdcRemain > 0 && isKyber) {
            usdcContract.approve(getAddressKyberProxy(), usdcRemain);
            KyberInterface(getAddressKyberProxy()).trade.value(uint(0))(
                    getAddressUSDC(),
                    usdcRemain,
                    getAddressETH(),
                    address(this),
                    2**255,
                    0,
                    getAddressAdmin()
                );
        }
        ERC20Interface wethContract = ERC20Interface(getAddressWETH());
        uint wethBal = wethContract.balanceOf(address(this));
        wethContract.approve(getAddressWETH(), wethBal);
        wethContract.withdraw(wethBal);
        mintCEth(address(this).balance);
        emit LogLeverageCompoundUsdc(usdcToSwap, address(this).balance);
    }

}


contract InstaCompSaveUsdc is CompoundSave {

    uint public version;

    /**
     * @dev setting up variables on deployment
     * 1...2...3 versioning in each subsequent deployments
     */
    constructor(uint _version) public {
        version = _version;
    }

    function() external payable {}

}