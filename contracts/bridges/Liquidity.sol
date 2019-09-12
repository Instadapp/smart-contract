pragma solidity ^0.5.7;

interface RegistryInterface {
    function proxies(address) external view returns (address);
}

interface UserWalletInterface {
    function owner() external view returns (address);
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

interface CTokenInterface {
    function mint(uint mintAmount) external returns (uint); // For ERC20
    function redeem(uint redeemTokens) external returns (uint);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
    function borrow(uint borrowAmount) external returns (uint);
    function exchangeRateCurrent() external returns (uint);
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
    function balanceOf(address) external view returns (uint);
    function repayBorrow(uint repayAmount) external returns (uint); // For ERC20
    function borrowBalanceCurrent(address account) external returns (uint);
}

interface CETHInterface {
    function exchangeRateCurrent() external returns (uint);
    function mint() external payable; // For ETH
    function repayBorrow() external payable; // For ETH
    function transfer(address, uint) external returns (bool);
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

    function sub(uint a, uint b) internal pure returns (uint c) {
        require(b <= a, "SafeMath: subtraction overflow");
        c = a - b;
    }

}


contract Helper is DSMath {

    address public ethAddr = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public daiAddr = 0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359;
    address public usdcAddr = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public registry = 0x498b3BfaBE9F73db90D252bCD4Fa9548Cd0Fd981;
    address public comptrollerAddr = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;

    mapping (address => bool) isCToken;

    address payable public adminOne = 0xd8db02A498E9AFbf4A32BC006DC1940495b4e592;
    address payable public adminTwo = 0x0f0EBD0d7672362D11e0b6d219abA30b0588954E;

    address public cEth = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
    address public cDai = 0xF5DCe57282A584D2746FaF1593d3121Fcac444dC;
    address public cUsdc = 0x39AA39c021dfbaE8faC545936693aC917d5E7563;

}


contract ProvideLiquidity is Helper {

    mapping (address => mapping (address => uint)) public deposits;
    mapping (address => uint) public totalDeposits;

    event LogDepositToken(address tknAddr, address ctknAddr, uint amt);
    event LogWithdrawToken(address tknAddr, address ctknAddr, uint amt);
    event LogDepositCToken(address ctknAddr, uint amt);
    event LogWithdrawCToken(address ctknAddr, uint amt);

    /**
     * @dev Deposit Token for liquidity
     */
    function depositToken(address tknAddr, address ctknAddr, uint amt) public payable {
        if (tknAddr != ethAddr) {
            ERC20Interface tknContract = ERC20Interface(tknAddr);
            require(tknContract.transferFrom(msg.sender, address(this), amt), "Not enough tkn to deposit");
            CTokenInterface cTokenContract = CTokenInterface(ctknAddr);
            uint intialBal = tknContract.balanceOf(address(this));
            assert(cTokenContract.mint(amt) == 0);
            uint finalBal = tknContract.balanceOf(address(this));
            assert(intialBal != finalBal);
            uint exchangeRate = cTokenContract.exchangeRateCurrent();
            uint cTknAmt = wdiv(amt, exchangeRate);
            cTknAmt = wmul(cTknAmt, exchangeRate) <= amt ? cTknAmt : cTknAmt - 1;
            deposits[msg.sender][ctknAddr] += cTknAmt;
            totalDeposits[ctknAddr] += cTknAmt;
            emit LogDepositToken(tknAddr, ctknAddr, amt);
        } else {
            CETHInterface cEthContract = CETHInterface(ctknAddr);
            uint intialBal = address(this).balance;
            cEthContract.mint.value(msg.value)();
            uint finalBal = address(this).balance;
            assert(intialBal != finalBal);
            uint exchangeRate = cEthContract.exchangeRateCurrent();
            uint cEthAmt = wdiv(msg.value, exchangeRate);
            cEthAmt = wmul(cEthAmt, exchangeRate) <= msg.value ? cEthAmt : cEthAmt - 1;
            deposits[msg.sender][ctknAddr] += cEthAmt;
            totalDeposits[ctknAddr] += cEthAmt;
            emit LogDepositToken(tknAddr, ctknAddr, msg.value);
        }
    }

    /**
     * @dev Withdraw Token from liquidity
     */
    function withdrawToken(address tknAddr, address ctknAddr, uint amt) public {
        require(deposits[msg.sender][ctknAddr] != 0, "Nothing to Withdraw");
        CTokenInterface cTokenContract = CTokenInterface(ctknAddr);
        uint exchangeRate = cTokenContract.exchangeRateCurrent();
        uint withdrawAmt = wdiv(amt, exchangeRate);
        uint tknAmt = amt;
        if (withdrawAmt > deposits[msg.sender][ctknAddr]) {
            withdrawAmt = deposits[msg.sender][ctknAddr] - 1;
            tknAmt = wmul(withdrawAmt, exchangeRate);
        }
        if (tknAddr != ethAddr) {
            ERC20Interface tknContract = ERC20Interface(tknAddr);
            uint initialTknBal = tknContract.balanceOf(address(this));
            require(cTokenContract.redeemUnderlying(tknAmt) == 0, "something went wrong");
            uint finalTknBal = tknContract.balanceOf(address(this));
            assert(initialTknBal != finalTknBal);
            require(ERC20Interface(tknAddr).transfer(msg.sender, tknAmt), "not enough tkn to Transfer");
        } else {
            uint initialTknBal = address(this).balance;
            require(cTokenContract.redeemUnderlying(tknAmt) == 0, "something went wrong");
            uint finalTknBal = address(this).balance;
            assert(initialTknBal != finalTknBal);
            msg.sender.transfer(tknAmt);
        }
        deposits[msg.sender][ctknAddr] -= withdrawAmt;
        totalDeposits[ctknAddr] -= withdrawAmt;
        emit LogWithdrawToken(tknAddr, ctknAddr, tknAmt);
    }

    /**
     * @dev Deposit CToken for liquidity
     */
    function depositCTkn(address ctknAddr, uint amt) public {
        require(CTokenInterface(ctknAddr).transferFrom(msg.sender, address(this), amt), "Nothing to deposit");
        deposits[msg.sender][ctknAddr] += amt;
        totalDeposits[ctknAddr] += amt;
        emit LogDepositCToken(ctknAddr, amt);
    }

    /**
     * @dev Withdraw CToken from liquidity
     */
    function withdrawCTkn(address ctknAddr, uint amt) public {
        require(deposits[msg.sender][ctknAddr] != 0, "Nothing to Withdraw");
        uint withdrawAmt = amt < deposits[msg.sender][ctknAddr] ? amt : deposits[msg.sender][ctknAddr];
        assert(CTokenInterface(ctknAddr).transfer(msg.sender, withdrawAmt));
        deposits[msg.sender][ctknAddr] -= withdrawAmt;
        totalDeposits[ctknAddr] -= withdrawAmt;
        emit LogWithdrawCToken(ctknAddr, withdrawAmt);
    }

}


contract AccessLiquidity is ProvideLiquidity {

    event LogRedeemTknAndTransfer(address tknAddr, address ctknAddr, uint amt);
    event LogMintTknBack(address tknAddr, address ctknAddr, uint amt);
    event LogBorrowTknAndTransfer(address tknAddr, address ctknAddr, uint amt);
    event LogPayBorrowBack(address tknAddr, address ctknAddr, uint amt);

    /**
     * FOR SECURITY PURPOSE
     * checks if only InstaDApp contract wallets can access the bridge
     */
    modifier isUserWallet {
        address userAdd = UserWalletInterface(msg.sender).owner();
        address walletAdd = RegistryInterface(registry).proxies(userAdd);
        require(walletAdd != address(0), "not-user-wallet");
        require(walletAdd == msg.sender, "not-wallet-owner");
        _;
    }

    /**
     * @dev Redeem CTokens and use them on InstaDApp's contract wallets
     */
    function redeemTknAndTransfer(address tknAddr, address ctknAddr, uint tknAmt) public isUserWallet {
        if (tknAmt > 0) {
            if (tknAddr != ethAddr) {
                CTokenInterface ctknContract = CTokenInterface(ctknAddr);
                ERC20Interface tknContract = ERC20Interface(tknAddr);
                uint initialTknBal = tknContract.balanceOf(address(this));
                assert(ctknContract.redeemUnderlying(tknAmt) == 0);
                uint finalTknBal = tknContract.balanceOf(address(this));
                assert(initialTknBal != finalTknBal);
                assert(tknContract.transfer(msg.sender, tknAmt));
            } else {
                CTokenInterface ctknContract = CTokenInterface(ctknAddr);
                uint initialTknBal = address(this).balance;
                assert(ctknContract.redeemUnderlying(tknAmt) == 0);
                uint finalTknBal = address(this).balance;
                assert(initialTknBal != finalTknBal);
                msg.sender.transfer(tknAmt);
            }
            emit LogRedeemTknAndTransfer(tknAddr, ctknAddr, tknAmt);
        }
    }

    /**
     * @dev Mint back redeemed tokens
     */
    function mintTknBack(address tknAddr, address ctknAddr, uint tknAmt) public payable isUserWallet {
        mintCTkn(tknAddr, ctknAddr, tknAmt);
    }

    /**
     * @dev Borrow tokens and use them on InstaDApp's contract wallets
     */
    function borrowTknAndTransfer(address tknAddr, address ctknAddr, uint tknAmt) public isUserWallet {
        if (tknAmt > 0) {
            CTokenInterface ctknContract = CTokenInterface(ctknAddr);
            if (tknAddr != ethAddr) {
                ERC20Interface tknContract = ERC20Interface(tknAddr);
                uint initialBal = tknContract.balanceOf(address(this));
                assert(ctknContract.borrow(tknAmt) == 0);
                uint finalBal = tknContract.balanceOf(address(this));
                assert(initialBal != finalBal);
                assert(tknContract.transfer(msg.sender, tknAmt));
            } else {
                uint initialBal = address(this).balance;
                assert(ctknContract.borrow(tknAmt) == 0);
                uint finalBal = address(this).balance;
                assert(initialBal != finalBal);
                msg.sender.transfer(tknAmt);
            }
            emit LogBorrowTknAndTransfer(tknAddr, ctknAddr, tknAmt);
        }
    }

    /**
     * @dev Payback borrow tokens
     */
    function payBorrowBack(address tknAddr, address ctknAddr, uint tknAmt) public payable isUserWallet {
        if (tknAmt > 0) {
            if (tknAddr != ethAddr) {
                ERC20Interface tknContract = ERC20Interface(tknAddr);
                CTokenInterface ctknContract = CTokenInterface(ctknAddr);
                uint borrowBal = ctknContract.borrowBalanceCurrent(address(this));
                uint initialBal = tknContract.balanceOf(address(this));
                assert(ctknContract.repayBorrow(borrowBal) == 0);
                uint finalBal = tknContract.balanceOf(address(this));
                assert(initialBal != finalBal);
                emit LogPayBorrowBack(tknAddr, ctknAddr, borrowBal);
            } else {
                CETHInterface cEthContract = CETHInterface(ctknAddr);
                uint borrowBal = cEthContract.borrowBalanceCurrent(address(this));
                uint initialBal = address(this).balance;
                cEthContract.repayBorrow.value(borrowBal);
                uint finalBal = address(this).balance;
                assert(initialBal != finalBal);
                emit LogPayBorrowBack(tknAddr, ctknAddr, borrowBal);
            }
        }
    }

    function mintCTkn(address tknAddr, address ctknAddr, uint tknAmt) internal {
        if (tknAmt > 0) {
            if (tknAddr != ethAddr) {
                CTokenInterface ctknContract = CTokenInterface(ctknAddr);
                ERC20Interface tknContract = ERC20Interface(tknAddr);
                uint tknBal = tknContract.balanceOf(address(this));
                assert(tknBal >= tknAmt);
                assert(ctknContract.mint(tknBal) == 0);
                uint finalTknBal = tknContract.balanceOf(address(this));
                assert(tknBal != finalTknBal);
                emit LogMintTknBack(tknAddr, ctknAddr, tknBal);
            } else {
                CETHInterface cEthContract = CETHInterface(ctknAddr);
                uint tknBal = address(this).balance;
                assert(tknBal >= tknAmt);
                cEthContract.mint.value(tknBal)();
                uint finalTknBal = address(this).balance;
                assert(tknBal != finalTknBal);
                emit LogMintTknBack(tknAddr, ctknAddr, tknBal);
            }
        }
    }

}


contract AdminStuff is AccessLiquidity {

    /**
     * Give approval to other addresses
     */
    function setApproval(address erc20, uint srcAmt, address to) public {
        require(msg.sender == adminOne || msg.sender == adminTwo, "Not admin address");
        ERC20Interface erc20Contract = ERC20Interface(erc20);
        uint tokenAllowance = erc20Contract.allowance(address(this), to);
        if (srcAmt > tokenAllowance) {
            erc20Contract.approve(to, uint(-1));
        }
    }

    /**
     * collect unmapped CToken
     */
    function collectCTokens(address ctkn) public {
        require(msg.sender == adminOne || msg.sender == adminTwo, "Not admin address");
        CTokenInterface cTokenContract = CTokenInterface(ctkn);
        uint cTokenBal = cTokenContract.balanceOf(address(this));
        uint withdrawAmt = sub(cTokenBal, totalDeposits[ctkn]);
        require(cTokenContract.transfer(msg.sender, withdrawAmt), "CToken Transfer failed");
    }

    /**
     * (HIGHLY UNLIKELY TO HAPPEN)
     * collecting Tokens/ETH other than CTokens
     */
    function collectTokens(address token) public {
        require(msg.sender == adminOne || msg.sender == adminTwo, "Not admin address");
        assert(isCToken[token] == false);
        if (token == ethAddr) {
            msg.sender.transfer(address(this).balance);
        } else {
            ERC20Interface tokenContract = ERC20Interface(token);
            uint tokenBal = tokenContract.balanceOf(address(this));
            require(tokenContract.transfer(msg.sender, tokenBal), "Transfer failed");
        }
    }

    /**
     * @dev Mint back redeemed tokens
     */
    function mintCollectedTkns(address tknAddr, address ctknAddr, uint tknAmt) public payable {
        require(msg.sender == adminOne || msg.sender == adminTwo, "Not admin address");
        mintCTkn(tknAddr, ctknAddr, tknAmt);
    }

    /**
     * Enter Compound Market to enable borrowing
     */
    function enterMarket(address[] memory cTknAddrArr) public {
        require(msg.sender == adminOne || msg.sender == adminTwo, "Not admin address");
        ComptrollerInterface troller = ComptrollerInterface(comptrollerAddr);
        troller.enterMarkets(cTknAddrArr);
    }

    /**
     * Enter Compound Market to disable borrowing
     */
    function exitMarket(address cErc20) public {
        require(msg.sender == adminOne || msg.sender == adminTwo, "Not admin address");
        ComptrollerInterface troller = ComptrollerInterface(comptrollerAddr);
        troller.exitMarket(cErc20);
    }

}


contract Liquidity is AdminStuff {

    /**
     * @dev setting up all required token approvals
     */
    constructor() public {
        address[] memory enterMarketArr = new address[](3);
        enterMarketArr[0] = cEth;
        enterMarketArr[1] = cDai;
        enterMarketArr[2] = cUsdc;
        enterMarket(enterMarketArr);
        setApproval(daiAddr, 2**255, cDai);
        setApproval(usdcAddr, 2**255, cUsdc);
        setApproval(cDai, 2**255, cDai);
        setApproval(cUsdc, 2**255, cUsdc);
        setApproval(cEth, 2**255, cEth);
    }

    function() external payable {}

}