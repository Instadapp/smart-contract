pragma solidity ^0.5.7;

interface TokenInterface {
    function allowance(address, address) external view returns (uint);
    function balanceOf(address) external view returns (uint);
    function approve(address, uint) external;
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
    function deposit() external payable;
    function withdraw(uint) external;
}

interface LiquidityInterface {
    function redeemTknAndTransfer(address tknAddr, address ctknAddr, uint tknAmt) external;
    function mintTknBack(address tknAddr, address ctknAddr, uint tknAmt) external;
    function borrowTknAndTransfer(address tknAddr, address ctknAddr, uint tknAmt) external;
    function payBorrowBack(address tknAddr, address ctknAddr, uint tknAmt) external;
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


contract DSMath {

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

    // /**
    //  * @dev get MakerDAO CDP engine
    //  */
    // function getSaiTubAddress() public pure returns (address sai) {
    //     sai = 0x448a5065aeBB8E423F0896E6c5D525C040f59af3;
    // }

    // /**
    //  * @dev get MakerDAO Oracle for ETH price
    //  */
    // function getOracleAddress() public pure returns (address oracle) {
    //     oracle = 0x729D19f657BD0614b4985Cf1D82531c67569197B;
    // }

    // /**
    //  * @dev get uniswap MKR exchange
    //  */
    // function getUniswapMKRExchange() public pure returns (address ume) {
    //     ume = 0x2C4Bd064b998838076fa341A83d007FC2FA50957;
    // }

    // /**
    //  * @dev get uniswap DAI exchange
    //  */
    // function getUniswapDAIExchange() public pure returns (address ude) {
    //     ude = 0x09cabEC1eAd1c0Ba254B09efb3EE13841712bE14;
    // }

    /**
     * @dev get InstaDApp Liquidity contract
     */
    function getLiquidityAddr() public pure returns (address liquidity) {
        liquidity = 0x2C717BFE76556fC7730f287f9B108Da4722d6065;
    }

    /**
     * @dev get Compound Comptroller Address
     */
    function getComptrollerAddress() public pure returns (address troller) {
        troller = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    }

    // /**
    //  * @dev get Compound Oracle Address
    //  */
    // function getCompOracleAddress() public pure returns (address troller) {
    //     troller = 0xe7664229833AE4Abf4E269b8F23a86B657E2338D;
    // }

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


contract FulcrumHelper is Helper {

    // TODO: Fill in with helper functions
    event FulcrumHelperPlaceholder();

}


contract CompoundHelper is FulcrumHelper {

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


contract FulcrumResolver is CompoundHelper {

    // TODO: Fill in with resolver functions
    event FulcrumResolverPlaceholder();

}


contract CompoundResolver is FulcrumResolver {

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
    function borrowDAIComp(uint daiAmt) internal {
        enterMarket(getCDAIAddress());
        require(CTokenInterface(getCDAIAddress()).borrow(daiAmt) == 0, "got collateral?");
        // Returning Liquidity to Liquidity Contract
        require(TokenInterface(getDAIAddress()).transfer(getLiquidityAddr(), daiAmt), "Not-enough-DAI");
        LiquidityInterface(getLiquidityAddr()).payBorrowBack(getDAIAddress(), getCDAIAddress(), daiAmt);
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
    function repayDaiComp(uint tokenAmt) internal returns (uint wipeAmt) {
        CERC20Interface cToken = CERC20Interface(getCDAIAddress());
        uint daiBorrowed = cToken.borrowBalanceCurrent(address(this));
        wipeAmt = tokenAmt < daiBorrowed ? tokenAmt : daiBorrowed;
        // Getting Liquidity from Liquidity Contract
        LiquidityInterface(getLiquidityAddr()).borrowTknAndTransfer(getDAIAddress(), getCDAIAddress(), wipeAmt);
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
    function mintAndBorrowComp(uint ethAmt, uint daiAmt) internal {
        mintCEth(ethAmt);
        borrowDAIComp(daiAmt);
    }

    /**
     * @dev run payback & redeem together
     */
    function paybackAndRedeemComp(uint ethCol, uint daiDebt) internal returns (uint ethAmt, uint daiAmt) {
        daiAmt = repayDaiComp(daiDebt);
        ethAmt = redeemCETH(ethCol);
    }

    /**
     * @dev Check if entered amt is valid or not (Used in makerToCompound)
     */
    function checkCompound(uint ethAmt, uint daiAmt) internal returns (uint ethCol, uint daiDebt) {
        CTokenInterface cEthContract = CTokenInterface(getCETHAddress());
        uint cEthBal = cEthContract.balanceOf(msg.sender);
        uint ethExchangeRate = cEthContract.exchangeRateCurrent();
        ethCol = wmul(cEthBal, ethExchangeRate);
        ethCol = wdiv(ethCol, ethExchangeRate) <= cEthBal ? ethCol : ethCol - 1;
        ethCol = ethCol <= ethAmt ? ethCol : ethAmt; // Set Max if amount is greater than the Col user have

        daiDebt = CERC20Interface(getCDAIAddress()).borrowBalanceCurrent(msg.sender);
        daiDebt = daiDebt <= daiAmt ? daiDebt : daiAmt; // Set Max if amount is greater than the Debt user have
    }

}


contract Bridge is CompoundResolver {

    event LogFulcrumToCompound(uint ethAmt, uint daiAmt);
    event LogCompoundToFulcrum(uint ethAmt, uint daiAmt);

    // /**
    //  * @dev convert Maker CDP into Compound Collateral
    //  */
    // function makerToCompound(uint cdpId, uint ethQty, uint daiQty) public {
    //     (uint ethAmt, uint daiDebt) = checkCDP(bytes32(cdpId), ethQty, daiQty);
    //     uint daiAmt = wipeAndFreeMaker(cdpId, ethAmt, daiDebt); // Getting Liquidity inside Wipe function
    //     enterMarket(getCETHAddress());
    //     enterMarket(getCDAIAddress());
    //     mintAndBorrowComp(ethAmt, daiAmt); // Returning Liquidity inside Borrow function
    //     emit LogMakerToCompound(ethAmt, daiAmt);
    // }

    // /**
    //  * @dev convert Compound Collateral into Maker CDP
    //  * @param cdpId = 0, if user don't have any CDP
    //  */
    // function compoundToMaker(uint cdpId, uint ethQty, uint daiQty) public {
    //     uint cdpNum = cdpId > 0 ? cdpId : open();
    //     (uint ethCol, uint daiDebt) = checkCompound(ethQty, daiQty);
    //     (uint ethAmt, uint daiAmt) = paybackAndRedeemComp(ethCol, daiDebt); // Getting Liquidity inside Wipe function
    //     ethAmt = ethAmt < address(this).balance ? ethAmt : address(this).balance;
    //     lockAndDrawMaker(cdpNum, ethAmt, daiAmt); // Returning Liquidity inside Borrow function
    //     emit LogCompoundToMaker(ethAmt, daiAmt);
    // }

}


contract InstaFulcrumCompBridge is Bridge {

    function() external payable {}

}