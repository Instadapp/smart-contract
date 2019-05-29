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
    function borrowBalanceCurrent(address account) external returns (uint);
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
}

interface CETHInterface {
    function mint() external payable; // For ETH
    function repayBorrow() external payable; // For ETH
    function repayBorrowBehalf(address borrower) external payable; // For ETH
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
     * @dev setting allowance to kyber for the "user proxy" if required
     * @param token is the token address
     */
    function setApproval(address token, uint srcAmt, address to) internal {
        ERC20Interface erc20Contract = ERC20Interface(token);
        uint tokenAllowance = erc20Contract.allowance(address(this), to);
        if (srcAmt > tokenAllowance) {
            erc20Contract.approve(to, 2**255);
        }
    }

    /**
     * @dev get Compound Comptroller
     */
    function getComptrollerAddress() public pure returns (address troller) {
        troller = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    }

    /**
     * @dev get CETH Address
     */
    function getCETHAddress() public pure returns (address cEthAdd) {
        cEthAdd = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
    }

}


contract CompoundResolver is Helpers {

    function enterMarkets(address[] calldata cTokensAdd) external returns (uint[] memory isSuccess) {
        isSuccess = ComptrollerInterface(getComptrollerAddress()).enterMarkets(cTokensAdd);
    }

    function exitMarket(address cTokensAdd) external returns (uint isSuccess) {
        isSuccess = ComptrollerInterface(getComptrollerAddress()).exitMarket(cTokensAdd);
    }

    function mintCETH() external payable {
        CETHInterface cToken = CETHInterface(getCETHAddress());
        cToken.mint.value(msg.value)();
    }

    function mintCToken(address erc20, address cErc20, uint tokenAmt) external {
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

    function redeem(address cErc20, uint cTokenAmt) external {
        CTokenInterface cToken = CTokenInterface(cErc20);
        uint toBurn = cToken.balanceOf(address(this));
        if (toBurn > cTokenAmt) {
            toBurn = cTokenAmt;
        }
        setApproval(cErc20, toBurn, cErc20);
        require(cToken.redeem(toBurn) == 0, "something went wrong");
    }

    function redeemUnderlying(address cErc20, uint tokenAmt) external {
        CTokenInterface cToken = CTokenInterface(cErc20);
        setApproval(cErc20, 10**50, cErc20);
        require(cToken.redeemUnderlying(tokenAmt) == 0, "something went wrong");
    }

    function borrow(address erc20, address cErc20, uint tokenAmt) external {
        require(CTokenInterface(cErc20).borrow(tokenAmt) == 0, "got collateral?");
        ERC20Interface(erc20).transfer(msg.sender, tokenAmt);
    }

    function repayEth() external payable {
        CETHInterface cToken = CETHInterface(getCETHAddress());
        cToken.repayBorrow.value(msg.value)();
    }

    function repaytoken(address erc20, address cErc20, uint tokenAmt) external payable {
        CERC20Interface cToken = CERC20Interface(cErc20);
        ERC20Interface token = ERC20Interface(erc20);
        uint toRepay = token.balanceOf(msg.sender);
        if (toRepay > tokenAmt) {
            toRepay = tokenAmt;
        }
        setApproval(erc20, toRepay, cErc20);
        token.transferFrom(msg.sender, address(this), toRepay);
        require(cToken.repayBorrow(toRepay) == 0, "transfer approved?");
    }

    function repayEthBehalf(address borrower) external payable {
        CETHInterface cToken = CETHInterface(getCETHAddress());
        cToken.repayBorrowBehalf.value(msg.value)(borrower);
    }

    function repaytokenBehalf(
        address borrower,
        address erc20,
        address cErc20,
        uint tokenAmt
    ) external payable
    {
        CERC20Interface cToken = CERC20Interface(cErc20);
        ERC20Interface token = ERC20Interface(erc20);
        uint toRepay = token.balanceOf(msg.sender);
        if (toRepay > tokenAmt) {
            toRepay = tokenAmt;
        }
        setApproval(erc20, toRepay, cErc20);
        uint tokenAllowance = token.allowance(address(this), cErc20);
        if (toRepay > tokenAllowance) {
            token.approve(cErc20, toRepay);
        }
        token.transferFrom(msg.sender, address(this), toRepay);
        require(cToken.repayBorrowBehalf(borrower, tokenAmt) == 0, "transfer approved?");
    }


}