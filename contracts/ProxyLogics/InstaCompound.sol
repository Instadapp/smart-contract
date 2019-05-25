pragma solidity ^0.5.0;

interface CTokenInterface {
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
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256 balance);
    function supplyRatePerBlock() external view returns (uint);
    function totalReserves() external view returns (uint);
    function reserveFactorMantissa() external view returns (uint);
}