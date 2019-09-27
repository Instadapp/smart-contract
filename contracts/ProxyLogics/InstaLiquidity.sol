pragma solidity ^0.5.7;

interface ERC20Interface {
    function allowance(address, address) external view returns (uint);
    function balanceOf(address) external view returns (uint);
    function approve(address, uint) external;
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
}

interface CTokenInterface {
    function mint(uint mintAmount) external returns (uint); // For ERC20
    function redeem(uint redeemTokens) external returns (uint);
    function borrow(uint borrowAmount) external returns (uint);
    function exchangeRateCurrent() external returns (uint);
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
    function balanceOf(address) external view returns (uint);
    function underlying() external view returns (address);
}

interface CETHInterface {
    function exchangeRateCurrent() external returns (uint);
    function mint() external payable; // For ETH
    function transfer(address, uint) external returns (bool);
    function balanceOf(address) external view returns (uint);
}

interface LiquidityInterface {
    function depositCTkn(address ctknAddr, uint amt) external;
    function withdrawCTkn(address ctknAddr, uint amt) external returns(uint ctknAmt);
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

    function sub(uint a, uint b) internal pure returns (uint c) {
        require(b <= a, "SafeMath: subtraction overflow");
        c = a - b;
    }

}


contract Helper is DSMath {

    /**
     * @dev get ethereum address for trade
     */
    function getEthAddr() public pure returns (address eth) {
        eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }

    function getCEthAddr() public pure returns(address ceth) {
        ceth = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
    }

    function getComptrollerAddr() public pure returns (address troller) {
        troller = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    }

    function getLiquidityAddr() public pure returns (address liquidity) {
        liquidity = 0x7281Db02c62e2966d5Cd20504B7C4C6eF4bD48E1;
    }

    /**
     * @dev setting allowance to compound for the "user proxy" if required
     */
    function setApproval(address erc20, uint srcAmt, address to) internal {
        ERC20Interface erc20Contract = ERC20Interface(erc20);
        uint tokenAllowance = erc20Contract.allowance(address(this), to);
        if (srcAmt > tokenAllowance) {
            erc20Contract.approve(to, srcAmt);
        }
    }

}


contract ProvideLiquidity is Helper {

    event LogDepositToken(address tknAddr, uint amt);
    event LogWithdrawToken(address tknAddr, uint amt);
    event LogDepositCToken(address ctknAddr, uint amt);
    event LogWithdrawCToken(address ctknAddr, uint amt);

    /**
     * @dev Deposit Token to liquidity.
     */
    function depositToken(address ctknAddr, uint amt) public payable {
        if (ctknAddr != getCEthAddr()) {
            CTokenInterface cTokenContract = CTokenInterface(ctknAddr);
            address tknAddr = cTokenContract.underlying();
            require(ERC20Interface(tknAddr).transferFrom(msg.sender, address(this), amt), "Not enough tkn to deposit");
            setApproval(tknAddr, amt, ctknAddr);
            assert(cTokenContract.mint(amt) == 0);
            uint exchangeRate = cTokenContract.exchangeRateCurrent();
            uint cTknAmt = wdiv(amt, exchangeRate);
            uint cTknBal = cTokenContract.balanceOf(address(this));
            cTknAmt = cTknAmt <= cTknBal ? cTknAmt : cTknBal;
            setApproval(ctknAddr, cTknAmt, getLiquidityAddr());
            LiquidityInterface(getLiquidityAddr()).depositCTkn(ctknAddr, cTknAmt);
            emit LogDepositToken(tknAddr, amt);
        } else {
            CETHInterface cEthContract = CETHInterface(ctknAddr);
            cEthContract.mint.value(msg.value)();
            uint exchangeRate = cEthContract.exchangeRateCurrent();
            uint cEthAmt = wdiv(msg.value, exchangeRate);
            uint cEthBal = cEthContract.balanceOf(address(this));
            cEthAmt = cEthAmt <= cEthBal ? cEthAmt : cEthBal;
            setApproval(ctknAddr, cEthAmt, getLiquidityAddr());
            LiquidityInterface(getLiquidityAddr()).depositCTkn(ctknAddr, cEthAmt);
            emit LogDepositToken(getEthAddr(), amt);
        }
    }

    /**
     * @dev Withdraw Token from liquidity.
     */
    function withdrawToken(address ctknAddr, uint amt) public {
        CTokenInterface cTokenContract = CTokenInterface(ctknAddr);
        uint exchangeRate = cTokenContract.exchangeRateCurrent();
        uint withdrawAmt = wdiv(amt, exchangeRate); // withdraw CToken Amount
        withdrawAmt = LiquidityInterface(getLiquidityAddr()).withdrawCTkn(ctknAddr, withdrawAmt);
        if (ctknAddr != getCEthAddr()) {
            require(cTokenContract.redeem(withdrawAmt) == 0, "something went wrong");
            uint tknAmt = wmul(withdrawAmt, exchangeRate);
            address tknAddr = cTokenContract.underlying();
            uint tknBal = ERC20Interface(tknAddr).balanceOf(address(this));
            tknAmt = tknAmt <= tknBal ? tknAmt : tknBal;
            require(ERC20Interface(tknAddr).transfer(msg.sender, tknAmt), "not enough tkn to Transfer");
            emit LogWithdrawToken(tknAddr, tknAmt);
        } else {
            require(cTokenContract.redeem(withdrawAmt) == 0, "something went wrong");
            uint ethAmt = wmul(withdrawAmt, exchangeRate);
            uint ethBal = address(this).balance;
            ethAmt = ethAmt <= ethBal ? ethAmt : ethBal;
            msg.sender.transfer(ethAmt);
            emit LogWithdrawToken(getEthAddr(), ethAmt);
        }
    }

    /**
     * @dev Deposit CToken in liquidity
     */
    function depositCTkn(address ctknAddr, uint amt) public {
        require(CTokenInterface(ctknAddr).transferFrom(msg.sender, address(this), amt), "Nothing to deposit");
        setApproval(ctknAddr, amt, getLiquidityAddr());
        LiquidityInterface(getLiquidityAddr()).depositCTkn(ctknAddr, amt);
        emit LogDepositCToken(ctknAddr, amt);
    }

    /**
     * @dev Withdraw CToken from liquidity
     */
    function withdrawCTkn(address ctknAddr, uint amt) public {
        uint withdrawAmt = LiquidityInterface(getLiquidityAddr()).withdrawCTkn(ctknAddr, amt);
        assert(CTokenInterface(ctknAddr).transfer(msg.sender, withdrawAmt));
        emit LogWithdrawCToken(ctknAddr, withdrawAmt);
    }

}


contract InstaLiquidity is ProvideLiquidity {

    function() external payable {}

}