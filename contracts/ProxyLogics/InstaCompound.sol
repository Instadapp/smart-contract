pragma solidity ^0.5.7;

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
        // troller = 0x2EAa9D77AE4D8f9cdD9FAAcd44016E746485bddb; // Rinkeby
        // troller = 0x3CA5a0E85aD80305c2d2c4982B2f2756f1e747a5; // Kovan
    }

    /**
     * @dev Transfer ETH/ERC20 to user
     */
    function transferToken(address erc20) internal {
        if (erc20 == getAddressETH()) {
            msg.sender.transfer(address(this).balance);
        } else {
            ERC20Interface erc20Contract = ERC20Interface(erc20);
            uint srcBal = erc20Contract.balanceOf(address(this));
            if (srcBal > 0) {
                erc20Contract.transfer(msg.sender, srcBal);
            }
        }
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


contract CompoundResolver is Helpers {

    event LogMint(address erc20, address cErc20, uint tokenAmt, address owner);
    event LogRedeem(address erc20, address cErc20, uint tokenAmt, address owner);
    event LogBorrow(address erc20, address cErc20, uint tokenAmt, address owner);
    event LogRepay(address erc20, address cErc20, uint tokenAmt, address owner);
    event LogRepayBehalf(address borrower, address erc20, address cErc20, uint tokenAmt, address owner);

    /**
     * @dev Deposit ETH/ERC20 and mint Compound Tokens
     */
    function mintCToken(address erc20, address cErc20, uint tokenAmt) external payable {
        enterMarket(cErc20);
        if (erc20 == getAddressETH()) {
            CETHInterface cToken = CETHInterface(cErc20);
            cToken.mint.value(msg.value)();
        } else {
            ERC20Interface token = ERC20Interface(erc20);
            uint toDeposit = token.balanceOf(msg.sender);
            if (toDeposit > tokenAmt) {
                toDeposit = tokenAmt;
            }
            token.transferFrom(msg.sender, address(this), toDeposit);
            CERC20Interface cToken = CERC20Interface(cErc20);
            setApproval(erc20, toDeposit, cErc20);
            assert(cToken.mint(toDeposit) == 0);
        }
        emit LogMint(
            erc20,
            cErc20,
            tokenAmt,
            address(this)
        );
    }

    /**
     * @dev Redeem ETH/ERC20 and burn Compound Tokens
     * @param cTokenAmt Amount of CToken To burn
     */
    function redeemCToken(address erc20, address cErc20, uint cTokenAmt) external {
        CTokenInterface cToken = CTokenInterface(cErc20);
        uint toBurn = cToken.balanceOf(address(this));
        if (toBurn > cTokenAmt) {
            toBurn = cTokenAmt;
        }
        setApproval(cErc20, toBurn, cErc20);
        require(cToken.redeem(toBurn) == 0, "something went wrong");
        transferToken(erc20);
        uint tokenReturned = wmul(toBurn, cToken.exchangeRateCurrent());
        emit LogRedeem(
            erc20,
            cErc20,
            tokenReturned,
            address(this)
        );
    }

    /**
     * @dev Redeem ETH/ERC20 and mint Compound Tokens
     * @param tokenAmt Amount of token To Redeem
     */
    function redeemUnderlying(address erc20, address cErc20, uint tokenAmt) external {
        CTokenInterface cToken = CTokenInterface(cErc20);
        setApproval(cErc20, 10**50, cErc20);
        uint toBurn = cToken.balanceOf(address(this));
        uint tokenToReturn = wmul(toBurn, cToken.exchangeRateCurrent());
        if (tokenToReturn > tokenAmt) {
            tokenToReturn = tokenAmt;
        }
        require(cToken.redeemUnderlying(tokenToReturn) == 0, "something went wrong");
        transferToken(erc20);
        emit LogRedeem(
            erc20,
            cErc20,
            tokenToReturn,
            address(this)
        );
    }

    /**
     * @dev borrow ETH/ERC20
     */
    function borrow(address erc20, address cErc20, uint tokenAmt) external {
        enterMarket(cErc20);
        require(CTokenInterface(cErc20).borrow(tokenAmt) == 0, "got collateral?");
        transferToken(erc20);
        emit LogBorrow(
            erc20,
            cErc20,
            tokenAmt,
            address(this)
        );
    }

    /**
     * @dev Pay Debt ETH/ERC20
     */
    function repayToken(address erc20, address cErc20, uint tokenAmt) external payable {
        if (erc20 == getAddressETH()) {
            CETHInterface cToken = CETHInterface(cErc20);
            uint toRepay = msg.value;
            uint borrows = cToken.borrowBalanceCurrent(address(this));
            if (toRepay > borrows) {
                toRepay = borrows;
                msg.sender.transfer(msg.value - toRepay);
            }
            cToken.repayBorrow.value(toRepay)();
            emit LogRepay(
                erc20,
                cErc20,
                toRepay,
                address(this)
            );
        } else {
            CERC20Interface cToken = CERC20Interface(cErc20);
            ERC20Interface token = ERC20Interface(erc20);
            uint toRepay = token.balanceOf(msg.sender);
            uint borrows = cToken.borrowBalanceCurrent(address(this));
            if (toRepay > tokenAmt) {
                toRepay = tokenAmt;
            }
            if (toRepay > borrows) {
                toRepay = borrows;
            }
            setApproval(erc20, toRepay, cErc20);
            token.transferFrom(msg.sender, address(this), toRepay);
            require(cToken.repayBorrow(toRepay) == 0, "transfer approved?");
            emit LogRepay(
                erc20,
                cErc20,
                toRepay,
                address(this)
            );
        }
    }

    /**
     * @dev Pay Debt for someone else
     */
    function repaytokenBehalf(
        address borrower,
        address erc20,
        address cErc20,
        uint tokenAmt
    ) external payable
    {
        if (erc20 == getAddressETH()) {
            CETHInterface cToken = CETHInterface(cErc20);
            uint toRepay = msg.value;
            uint borrows = cToken.borrowBalanceCurrent(borrower);
            if (toRepay > borrows) {
                toRepay = borrows;
                msg.sender.transfer(msg.value - toRepay);
            }
            cToken.repayBorrowBehalf.value(toRepay)(borrower);
            emit LogRepayBehalf(
                borrower,
                erc20,
                cErc20,
                toRepay,
                address(this)
            );
        } else {
            CERC20Interface cToken = CERC20Interface(cErc20);
            ERC20Interface token = ERC20Interface(erc20);
            uint toRepay = token.balanceOf(msg.sender);
            uint borrows = cToken.borrowBalanceCurrent(borrower);
            if (toRepay > tokenAmt) {
                toRepay = tokenAmt;
            }
            if (toRepay > borrows) {
                toRepay = borrows;
            }
            setApproval(erc20, toRepay, cErc20);
            token.transferFrom(msg.sender, address(this), toRepay);
            require(cToken.repayBorrowBehalf(borrower, toRepay) == 0, "transfer approved?");
            emit LogRepayBehalf(
                borrower,
                erc20,
                cErc20,
                toRepay,
                address(this)
            );
        }
    }

}


contract InstaCompound is CompoundResolver {

    function() external payable {}

}