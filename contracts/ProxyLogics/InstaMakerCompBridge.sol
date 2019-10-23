pragma solidity ^0.5.7;

interface TubInterface {
    function open() external returns (bytes32);
    function join(uint) external;
    function exit(uint) external;
    function lock(bytes32, uint) external;
    function free(bytes32, uint) external;
    function draw(bytes32, uint) external;
    function wipe(bytes32, uint) external;
    function give(bytes32, address) external;
    function shut(bytes32) external;
    function cups(bytes32) external view returns (address, uint, uint, uint);
    function gem() external view returns (TokenInterface);
    function gov() external view returns (TokenInterface);
    function skr() external view returns (TokenInterface);
    function sai() external view returns (TokenInterface);
    function ink(bytes32) external view returns (uint);
    function tab(bytes32) external returns (uint);
    function rap(bytes32) external returns (uint);
    function per() external view returns (uint);
    function pep() external view returns (PepInterface);
}

interface TokenInterface {
    function allowance(address, address) external view returns (uint);
    function balanceOf(address) external view returns (uint);
    function approve(address, uint) external;
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
    function deposit() external payable;
    function withdraw(uint) external;
}

interface PepInterface {
    function peek() external returns (bytes32, bool);
}

interface MakerOracleInterface {
    function read() external view returns (bytes32);
}

interface UniswapExchange {
    function getEthToTokenOutputPrice(uint256 tokensBought) external view returns (uint256 ethSold);
    function getTokenToEthOutputPrice(uint256 ethBought) external view returns (uint256 tokensSold);
    function tokenToTokenSwapOutput(
        uint256 tokensBought,
        uint256 maxTokensSold,
        uint256 maxEthSold,
        uint256 deadline,
        address tokenAddr
        ) external returns (uint256  tokensSold);
}

interface PoolInterface {
    function accessToken(address[] calldata ctknAddr, uint[] calldata tknAmt, bool isCompound) external;
    function paybackToken(address[] calldata ctknAddr, bool isCompound) external payable;
}

interface CTokenInterface {
    function redeem(uint redeemTokens) external returns (uint);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
    function borrow(uint borrowAmount) external returns (uint);
    function liquidateBorrow(address borrower, uint repayAmount, address cTokenCollateral) external returns (uint);
    function liquidateBorrow(address borrower, address cTokenCollateral) external payable;
    function exchangeRateCurrent() external returns (uint);
    function getCash() external view returns (uint);
    function totalBorrowsCurrent() external returns (uint);
    function borrowRatePerBlock() external view returns (uint);
    function supplyRatePerBlock() external view returns (uint);
    function totalReserves() external view returns (uint);
    function reserveFactorMantissa() external view returns (uint);
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
    function repayBorrowBehalf(address borrower, uint repayAmount) external returns (uint); // For ERC20
    function borrowBalanceCurrent(address account) external returns (uint);
}

interface CETHInterface {
    function mint() external payable; // For ETH
    function repayBorrow() external payable; // For ETH
    function repayBorrowBehalf(address borrower) external payable; // For ETH
    function borrowBalanceCurrent(address account) external returns (uint);
}

interface ComptrollerInterface {
    function enterMarkets(address[] calldata cTokens) external returns (uint[] memory);
    function exitMarket(address cTokenAddress) external returns (uint);
    function getAssetsIn(address account) external view returns (address[] memory);
    function getAccountLiquidity(address account) external view returns (uint, uint, uint);
}

interface CompOracleInterface {
    function getUnderlyingPrice(address) external view returns (uint);
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
    uint constant RAY = 10 ** 27;

    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), RAY / 2) / RAY;
    }

    function rdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, RAY), y / 2) / y;
    }

    function wmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }

    function wdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, WAD), y / 2) / y;
    }

}


contract Helper is DSMath {

    /**
     * @dev get ethereum address for trade
     */
    function getAddressETH() public pure returns (address eth) {
        eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }

    /**
     * @dev get MakerDAO CDP engine
     */
    function getSaiTubAddress() public pure returns (address sai) {
        sai = 0x448a5065aeBB8E423F0896E6c5D525C040f59af3;
    }

    /**
     * @dev get MakerDAO Oracle for ETH price
     */
    function getOracleAddress() public pure returns (address oracle) {
        oracle = 0x729D19f657BD0614b4985Cf1D82531c67569197B;
    }

    /**
     * @dev get uniswap MKR exchange
     */
    function getUniswapMKRExchange() public pure returns (address ume) {
        ume = 0x2C4Bd064b998838076fa341A83d007FC2FA50957;
    }

    /**
     * @dev get uniswap DAI exchange
     */
    function getUniswapDAIExchange() public pure returns (address ude) {
        ude = 0x09cabEC1eAd1c0Ba254B09efb3EE13841712bE14;
    }

    /**
     * @dev get InstaDApp Liquidity contract
     */
    function getPoolAddr() public pure returns (address poolAddr) {
        poolAddr = 0x1564D040EC290C743F67F5cB11f3C1958B39872A;
    }

    /**
     * @dev get Compound Comptroller Address
     */
    function getComptrollerAddress() public pure returns (address troller) {
        troller = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    }

    /**
     * @dev get Compound Oracle Address
     */
    function getCompOracleAddress() public pure returns (address troller) {
        troller = 0xe7664229833AE4Abf4E269b8F23a86B657E2338D;
    }

    /**
     * @dev get CETH Address
     */
    function getCETHAddress() public pure returns (address cEth) {
        cEth = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
    }

    /**
     * @dev get DAI Address
     */
    function getDAIAddress() public pure returns (address dai) {
        dai = 0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359;
    }

    /**
     * @dev get MKR Address
     */
    function getMKRAddress() public pure returns (address dai) {
        dai = 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2;
    }

    /**
     * @dev get CDAI Address
     */
    function getCDAIAddress() public pure returns (address cDai) {
        cDai = 0xF5DCe57282A584D2746FaF1593d3121Fcac444dC;
    }

    /**
     * @dev setting allowance to compound contracts for the "user proxy" if required
     */
    function setApproval(address erc20, uint srcAmt, address to) internal {
        TokenInterface erc20Contract = TokenInterface(erc20);
        uint tokenAllowance = erc20Contract.allowance(address(this), to);
        if (srcAmt > tokenAllowance) {
            erc20Contract.approve(to, uint(-1));
        }
    }

}


contract MakerHelper is Helper {

    event LogOpen(uint cdpNum, address owner);
    event LogLock(uint cdpNum, uint amtETH, uint amtPETH, address owner);
    event LogFree(uint cdpNum, uint amtETH, uint amtPETH, address owner);
    event LogDraw(uint cdpNum, uint amtDAI, address owner);
    event LogWipe(uint cdpNum, uint daiAmt, uint mkrFee, uint daiFee, address owner);
    event LogShut(uint cdpNum);

    /**
     * @dev Allowance to Maker's contract
     */
    function setMakerAllowance(TokenInterface _token, address _spender) internal {
        if (_token.allowance(address(this), _spender) != uint(-1)) {
            _token.approve(_spender, uint(-1));
        }
    }

    /**
     * @dev CDP stats by Bytes
     */
    function getCDPStats(bytes32 cup) internal view returns (uint ethCol, uint daiDebt) {
        TubInterface tub = TubInterface(getSaiTubAddress());
        (, uint pethCol, uint debt,) = tub.cups(cup);
        ethCol = rmul(pethCol, tub.per()); // get ETH col from PETH col
        daiDebt = debt;
    }

}


contract CompoundHelper is MakerHelper {

    event LogMint(address erc20, address cErc20, uint tokenAmt, address owner);
    event LogRedeem(address erc20, address cErc20, uint tokenAmt, address owner);
    event LogBorrow(address erc20, address cErc20, uint tokenAmt, address owner);
    event LogRepay(address erc20, address cErc20, uint tokenAmt, address owner);

    /**
     * @dev Compound Enter Market which allows borrowing
     */
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

}


contract InstaPoolResolver is CompoundHelper {

    function accessDai(uint daiAmt, bool isCompound) internal {
        address[] memory borrowAddr = new address[](1);
        uint[] memory borrowAmt = new uint[](1);
        borrowAddr[0] = getCDAIAddress();
        borrowAmt[0] = daiAmt;
        PoolInterface(getPoolAddr()).accessToken(borrowAddr, borrowAmt, isCompound);
    }

    function returnDai(uint daiAmt, bool isCompound) internal {
        address[] memory borrowAddr = new address[](1);
        borrowAddr[0] = getCDAIAddress();
        require(TokenInterface(getDAIAddress()).transfer(getPoolAddr(), daiAmt), "Not-enough-DAI");
        PoolInterface(getPoolAddr()).paybackToken(borrowAddr, isCompound);
    }

}


contract MakerResolver is InstaPoolResolver {

    /**
     * @dev Open new CDP
     */
    function open() internal returns (uint) {
        bytes32 cup = TubInterface(getSaiTubAddress()).open();
        emit LogOpen(uint(cup), address(this));
        return uint(cup);
    }

    /**
     * @dev transfer CDP ownership
     */
    function give(uint cdpNum, address nextOwner) internal {
        TubInterface(getSaiTubAddress()).give(bytes32(cdpNum), nextOwner);
    }

    function setWipeAllowances(TubInterface tub) internal { // to solve stack to deep error
        TokenInterface dai = tub.sai();
        TokenInterface mkr = tub.gov();
        setMakerAllowance(dai, getSaiTubAddress());
        setMakerAllowance(mkr, getSaiTubAddress());
        setMakerAllowance(dai, getUniswapDAIExchange());
    }

    /**
     * @dev Pay CDP debt
     */
    function wipe(uint cdpNum, uint _wad, bool isCompound) internal returns (uint daiAmt) {
        if (_wad > 0) {
            TubInterface tub = TubInterface(getSaiTubAddress());
            UniswapExchange daiEx = UniswapExchange(getUniswapDAIExchange());
            UniswapExchange mkrEx = UniswapExchange(getUniswapMKRExchange());

            bytes32 cup = bytes32(cdpNum);

            (address lad,,,) = tub.cups(cup);
            require(lad == address(this), "cup-not-owned");

            setWipeAllowances(tub);
            (bytes32 val, bool ok) = tub.pep().peek();

            // MKR required for wipe = Stability fees accrued in Dai / MKRUSD value
            uint mkrFee = wdiv(rmul(_wad, rdiv(tub.rap(cup), tub.tab(cup))), uint(val));

            uint daiFeeAmt = daiEx.getTokenToEthOutputPrice(mkrEx.getEthToTokenOutputPrice(mkrFee));
            daiAmt = add(_wad, daiFeeAmt);

            // Getting Liquidity from Liquidity Contract
            accessDai(daiAmt, isCompound);

            if (ok && val != 0) {
                daiEx.tokenToTokenSwapOutput(
                    mkrFee,
                    daiFeeAmt,
                    uint(999000000000000000000),
                    uint(1899063809), // 6th March 2030 GMT // no logic
                    getMKRAddress()
                );
            }

            tub.wipe(cup, _wad);

            emit LogWipe(
                cdpNum,
                daiAmt,
                mkrFee,
                daiFeeAmt,
                address(this)
            );

        }
    }

    /**
     * @dev Pay CDP debt
     */
    function wipeWithMkr(uint cdpNum, uint _wad, bool isCompound) internal {
        if (_wad > 0) {
            TubInterface tub = TubInterface(getSaiTubAddress());
            TokenInterface dai = tub.sai();
            TokenInterface mkr = tub.gov();

            bytes32 cup = bytes32(cdpNum);

            (address lad,,,) = tub.cups(cup);
            require(lad == address(this), "cup-not-owned");

            setMakerAllowance(dai, getSaiTubAddress());
            setMakerAllowance(mkr, getSaiTubAddress());

            (bytes32 val, bool ok) = tub.pep().peek();

            // MKR required for wipe = Stability fees accrued in Dai / MKRUSD value
            uint mkrFee = wdiv(rmul(_wad, rdiv(tub.rap(cup), tub.tab(cup))), uint(val));

            // Getting Liquidity from Liquidity Contract
            accessDai(_wad, isCompound);

            if (ok && val != 0) {
                require(mkr.transferFrom(msg.sender, address(this), mkrFee), "MKR-Allowance?");
            }

            tub.wipe(cup, _wad);

            emit LogWipe(
                cdpNum,
                _wad,
                mkrFee,
                0,
                address(this)
            );

        }
    }

    /**
     * @dev Withdraw CDP
     */
    function free(uint cdpNum, uint jam) internal {
        if (jam > 0) {
            bytes32 cup = bytes32(cdpNum);
            address tubAddr = getSaiTubAddress();

            TubInterface tub = TubInterface(tubAddr);
            TokenInterface peth = tub.skr();
            TokenInterface weth = tub.gem();

            uint ink = rdiv(jam, tub.per());
            ink = rmul(ink, tub.per()) <= jam ? ink : ink - 1;
            tub.free(cup, ink);

            setMakerAllowance(peth, tubAddr);

            tub.exit(ink);
            uint freeJam = weth.balanceOf(address(this)); // withdraw possible previous stuck WETH as well
            weth.withdraw(freeJam);
        }
    }

    /**
     * @dev Deposit Collateral
     */
    function lock(uint cdpNum, uint ethAmt) internal {
        if (ethAmt > 0) {
            bytes32 cup = bytes32(cdpNum);
            address tubAddr = getSaiTubAddress();

            TubInterface tub = TubInterface(tubAddr);
            TokenInterface weth = tub.gem();
            TokenInterface peth = tub.skr();

            (address lad,,,) = tub.cups(cup);
            require(lad == address(this), "cup-not-owned");

            weth.deposit.value(ethAmt)();

            uint ink = rdiv(ethAmt, tub.per());
            ink = rmul(ink, tub.per()) <= ethAmt ? ink : ink - 1;

            setMakerAllowance(weth, tubAddr);
            tub.join(ink);

            setMakerAllowance(peth, tubAddr);
            tub.lock(cup, ink);
        }
    }

    /**
     * @dev Borrow DAI Debt
     */
    function draw(uint cdpNum, uint _wad, bool isCompound) internal {
        bytes32 cup = bytes32(cdpNum);
        if (_wad > 0) {
            TubInterface tub = TubInterface(getSaiTubAddress());

            tub.draw(cup, _wad);

            // Returning Liquidity To Liquidity Contract
            returnDai(_wad, isCompound);
        }
    }

    /**
     * @dev Check if entered amt is valid or not (Used in makerToCompound)
     */
    function checkCDP(bytes32 cup, uint ethAmt, uint daiAmt) internal returns (uint ethCol, uint daiDebt) {
        TubInterface tub = TubInterface(getSaiTubAddress());
        ethCol = rmul(tub.ink(cup), tub.per()) - 1; // get ETH col from PETH col
        daiDebt = tub.tab(cup);
        daiDebt = daiAmt < daiDebt ? daiAmt : daiDebt; // if DAI amount > max debt. Set max debt
        ethCol = ethAmt < ethCol ? ethAmt : ethCol; // if ETH amount > max Col. Set max col
    }

    /**
     * @dev Run wipe & Free function together
     */
    function wipeAndFreeMaker(
        uint cdpNum,
        uint jam,
        uint _wad,
        bool isCompound,
        bool feeInMkr
    ) internal returns (uint daiAmt)
    {
        if (feeInMkr) {
            wipeWithMkr(cdpNum, _wad, isCompound);
            daiAmt = _wad;
        } else {
            daiAmt = wipe(cdpNum, _wad, isCompound);
        }
        free(cdpNum, jam);
    }

    /**
     * @dev Run Lock & Draw function together
     */
    function lockAndDrawMaker(
        uint cdpNum,
        uint jam,
        uint _wad,
        bool isCompound
    ) internal
    {
        lock(cdpNum, jam);
        draw(cdpNum, _wad, isCompound);
    }

}


contract CompoundResolver is MakerResolver {

    /**
     * @dev Deposit ETH and mint CETH
     */
    function mintCEth(uint tokenAmt) internal {
        enterMarket(getCETHAddress());
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
     * @dev borrow DAI
     */
    function borrowDAIComp(uint daiAmt, bool isCompound) internal {
        enterMarket(getCDAIAddress());
        require(CTokenInterface(getCDAIAddress()).borrow(daiAmt) == 0, "got collateral?");
        // Returning Liquidity to Liquidity Contract
        returnDai(daiAmt, isCompound);
        emit LogBorrow(
            getDAIAddress(),
            getCDAIAddress(),
            daiAmt,
            address(this)
        );
    }

    /**
     * @dev Pay DAI Debt
     */
    function repayDaiComp(uint tokenAmt, bool isCompound) internal returns (uint wipeAmt) {
        CERC20Interface cToken = CERC20Interface(getCDAIAddress());
        uint daiBorrowed = cToken.borrowBalanceCurrent(address(this));
        wipeAmt = tokenAmt < daiBorrowed ? tokenAmt : daiBorrowed;
        // Getting Liquidity from Liquidity Contract
        accessDai(wipeAmt, isCompound);
        setApproval(getDAIAddress(), wipeAmt, getCDAIAddress());
        require(cToken.repayBorrow(wipeAmt) == 0, "transfer approved?");
        emit LogRepay(
            getDAIAddress(),
            getCDAIAddress(),
            wipeAmt,
            address(this)
        );
    }

    /**
     * @dev Redeem CETH
     * @param tokenAmt Amount of token To Redeem
     */
    function redeemCETH(uint tokenAmt) internal returns(uint ethAmtReddemed) {
        CTokenInterface cToken = CTokenInterface(getCETHAddress());
        uint cethBal = cToken.balanceOf(address(this));
        uint exchangeRate = cToken.exchangeRateCurrent();
        uint cethInEth = wmul(cethBal, exchangeRate);
        setApproval(getCETHAddress(), 2**128, getCETHAddress());
        ethAmtReddemed = tokenAmt;
        if (tokenAmt > cethInEth) {
            require(cToken.redeem(cethBal) == 0, "something went wrong");
            ethAmtReddemed = cethInEth;
        } else {
            require(cToken.redeemUnderlying(tokenAmt) == 0, "something went wrong");
        }
        emit LogRedeem(
            getAddressETH(),
            getCETHAddress(),
            ethAmtReddemed,
            address(this)
        );
    }

    /**
     * @dev run mint & borrow together
     */
    function mintAndBorrowComp(uint ethAmt, uint daiAmt, bool isCompound) internal {
        mintCEth(ethAmt);
        borrowDAIComp(daiAmt, isCompound);
    }

    /**
     * @dev run payback & redeem together
     */
    function paybackAndRedeemComp(uint ethCol, uint daiDebt, bool isCompound) internal returns (uint ethAmt, uint daiAmt) {
        daiAmt = repayDaiComp(daiDebt, isCompound);
        ethAmt = redeemCETH(ethCol);
    }

    /**
     * @dev Check if entered amt is valid or not (Used in makerToCompound)
     */
    function checkCompound(uint ethAmt, uint daiAmt) internal returns (uint ethCol, uint daiDebt) {
        CTokenInterface cEthContract = CTokenInterface(getCETHAddress());
        uint cEthBal = cEthContract.balanceOf(address(this));
        uint ethExchangeRate = cEthContract.exchangeRateCurrent();
        ethCol = wmul(cEthBal, ethExchangeRate);
        ethCol = wdiv(ethCol, ethExchangeRate) <= cEthBal ? ethCol : ethCol - 1;
        ethCol = ethCol <= ethAmt ? ethCol : ethAmt; // Set Max if amount is greater than the Col user have

        daiDebt = CERC20Interface(getCDAIAddress()).borrowBalanceCurrent(address(this));
        daiDebt = daiDebt <= daiAmt ? daiDebt : daiAmt; // Set Max if amount is greater than the Debt user have
    }

}


contract InstaMakerCompBridge is CompoundResolver {

    event LogMakerToCompound(uint ethAmt, uint daiAmt);
    event LogCompoundToMaker(uint ethAmt, uint daiAmt);

    /**
     * @dev convert Maker CDP into Compound Collateral
     */
    function makerToCompound(
        uint cdpId,
        uint ethQty,
        uint daiQty,
        bool isCompound, // access Liquidity from Compound
        bool feeInMkr
        ) external
        {
        // subtracting 0.00000001 ETH from initialPoolBal to solve Compound 8 decimal CETH error.
        uint initialPoolBal = sub(getPoolAddr().balance, 10000000000);

        (uint ethAmt, uint daiDebt) = checkCDP(bytes32(cdpId), ethQty, daiQty);
        uint daiAmt = wipeAndFreeMaker(
            cdpId,
            ethAmt,
            daiDebt,
            isCompound,
            feeInMkr
        ); // Getting Liquidity inside Wipe function
        enterMarket(getCETHAddress());
        enterMarket(getCDAIAddress());
        mintAndBorrowComp(ethAmt, daiAmt, isCompound); // Returning Liquidity inside Borrow function

        uint finalPoolBal = getPoolAddr().balance;
        assert(finalPoolBal >= initialPoolBal);

        emit LogMakerToCompound(ethAmt, daiAmt);
    }

    /**
     * @dev convert Compound Collateral into Maker CDP
     * @param cdpId = 0, if user don't have any CDP
     */
    function compoundToMaker(
        uint cdpId,
        uint ethQty,
        uint daiQty,
        bool isCompound
    ) external
    {
        // subtracting 0.00000001 ETH from initialPoolBal to solve Compound 8 decimal CETH error.
        uint initialPoolBal = sub(getPoolAddr().balance, 10000000000);

        uint cdpNum = cdpId > 0 ? cdpId : open();
        (uint ethCol, uint daiDebt) = checkCompound(ethQty, daiQty);
        (uint ethAmt, uint daiAmt) = paybackAndRedeemComp(ethCol, daiDebt, isCompound); // Getting Liquidity inside Wipe function
        ethAmt = ethAmt < address(this).balance ? ethAmt : address(this).balance;
        lockAndDrawMaker(
            cdpNum,
            ethAmt,
            daiAmt,
            isCompound
        ); // Returning Liquidity inside Borrow function

        uint finalPoolBal = getPoolAddr().balance;
        assert(finalPoolBal >= initialPoolBal);

        emit LogCompoundToMaker(ethAmt, daiAmt);
    }

    function() external payable {}

}