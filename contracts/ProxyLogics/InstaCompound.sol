pragma solidity ^0.5.7;

interface CERC20Interface {
    function mint(uint mintAmount) external returns (uint); // For ERC20
    function mint() external payable; // For ETH
    function redeem(uint redeemTokens) external returns (uint);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
    function borrow(uint borrowAmount) external returns (uint);
    function repayBorrow(uint repayAmount) external returns (uint); // For ERC20
    function repayBorrow() external payable; // For ETH
    function repayBorrowBehalf(address borrower, uint repayAmount) external returns (uint); // For ERC20
    function repayBorrowBehalf(address borrower) external payable; // For ETH
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


contract Helpers {

    /**
     * @dev get Compound Comptroller
     */
    function getComptrollerAddress() public pure returns (address troller) {
        troller = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    }

    // Need to check at the end
    function exchangeRate(address cERC20) public returns (uint exchangeRateMantissa) {
        CERC20Interface cToken = CERC20Interface(cERC20);
        exchangeRateMantissa = cToken.exchangeRateCurrent();
    }

    function getCash(address cERC20) public view returns (uint cash) {
        CERC20Interface cToken = CERC20Interface(cERC20);
        cash = cToken.getCash();
    }

    // Need to check at the end
    function totalBorrow(address cERC20) public returns (uint borrows) {
        CERC20Interface cToken = CERC20Interface(cERC20);
        borrows = cToken.totalBorrowsCurrent();
    }

    // Need to check at the end
    function borrowBalance(address user, address cERC20) public returns (uint borrowAmt) {
        CERC20Interface cToken = CERC20Interface(cERC20);
        borrowAmt = cToken.borrowBalanceCurrent(user);
    }

}

