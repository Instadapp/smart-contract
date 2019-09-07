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
}

interface CETHInterface {
    function exchangeRateCurrent() external returns (uint);
    function mint() external payable; // For ETH
    function repayBorrow() external payable; // For ETH
    function transfer(address, uint) external returns (bool);
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
    address public registry = 0x498b3BfaBE9F73db90D252bCD4Fa9548Cd0Fd981;
    address public comptroller = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;

    mapping (address => bool) isCToken;

    address payable public adminOne = 0xd8db02A498E9AFbf4A32BC006DC1940495b4e592;
    address payable public adminTwo = 0xa7615CD307F323172331865181DC8b80a2834324;
    uint public fees = 0;

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

    function setAllowance(ERC20Interface _token, address _spender) internal {
        if (_token.allowance(address(this), _spender) != uint(-1)) {
            _token.approve(_spender, uint(-1));
        }
    }

}


contract ProvideLiquidity is Helper {

    // mapping (address => uint) public deposits; // amount of CDAI deposits
    // deposits CTokens mapping (address user => address CToken => uint TokenAmt)
    mapping (address => mapping (address => uint)) public deposits;
    mapping (address => uint) public totalDeposits;

    /**
     * @dev Deposit DAI for liquidity
     */
    function depositToken(address tknAddr, address ctknAddr, uint amt) public payable {
        if (tknAddr != ethAddr) {
            require(ERC20Interface(tknAddr).transferFrom(msg.sender, address(this), amt), "Nothing enough tkn to deposit");
            CTokenInterface cTokenContract = CTokenInterface(ctknAddr);
            assert(cTokenContract.mint(amt) == 0);
            uint exchangeRate = cTokenContract.exchangeRateCurrent();
            uint cTknAmt = wdiv(amt, exchangeRate);
            cTknAmt = wmul(cTknAmt, exchangeRate) <= amt ? cTknAmt : cTknAmt - 1;
            deposits[msg.sender][ctknAddr] += cTknAmt;
            totalDeposits[ctknAddr] += cTknAmt;
        } else {
            CETHInterface cEthContract = CETHInterface(ctknAddr);
            cEthContract.mint.value(msg.value)();
            uint exchangeRate = cEthContract.exchangeRateCurrent();
            uint cEthAmt = wdiv(msg.value, exchangeRate);
            cEthAmt = wmul(cEthAmt, exchangeRate) <= msg.value ? cEthAmt : cEthAmt - 1;
            deposits[msg.sender][ctknAddr] += cEthAmt;
            totalDeposits[ctknAddr] += cEthAmt;
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
            withdrawAmt = deposits[msg.sender][ctknAddr];
            tknAmt = wmul(withdrawAmt, exchangeRate);
        }
        if (tknAddr != ethAddr) {
            ERC20Interface tknContract = ERC20Interface(tknAddr);
            uint initialTknBal = tknContract.balanceOf(address(this));
            require(cTokenContract.redeem(withdrawAmt) == 0, "something went wrong");
            uint finalTknBal = tknContract.balanceOf(address(this));
            assert(initialTknBal != finalTknBal);
            require(ERC20Interface(tknAddr).transfer(msg.sender, tknAmt), "not enough tkn to Transfer");
        } else {
            uint initialTknBal = address(this).balance;
            require(cTokenContract.redeem(withdrawAmt) == 0, "something went wrong");
            uint finalTknBal = address(this).balance;
            assert(initialTknBal != finalTknBal);
            msg.sender.transfer(tknAmt);
        }
        deposits[msg.sender][ctknAddr] -= withdrawAmt;
        totalDeposits[ctknAddr] -= withdrawAmt;
    }

    /**
     * @dev Deposit CToken for liquidity
     */
    function depositCTkn(address ctknAddr, uint amt) public {
        CTokenInterface cTokenContract = CTokenInterface(ctknAddr);
        require(cTokenContract.transferFrom(msg.sender, address(this), amt) == true, "Nothing to deposit");
        deposits[msg.sender][ctknAddr] += amt;
        totalDeposits[ctknAddr] += amt;
    }

    /**
     * @dev Withdraw CToken from liquidity
     */
    function withdrawCTkn(address ctknAddr, uint amt) public {
        require(deposits[msg.sender][ctknAddr] != 0, "Nothing to Withdraw");
        uint withdrawAmt = amt;
        if (withdrawAmt > deposits[msg.sender][ctknAddr]) {
            withdrawAmt = deposits[msg.sender][ctknAddr];
        }
        require(CTokenInterface(ctknAddr).transfer(msg.sender, withdrawAmt), "Dai Transfer failed");
        deposits[msg.sender][ctknAddr] -= withdrawAmt;
        totalDeposits[ctknAddr] -= withdrawAmt;
    }

}


contract AccessLiquidity is ProvideLiquidity {

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
        }
    }

    function mintTknBack(address tknAddr, address ctknAddr, uint tknAmt) public payable {
        if (tknAmt > 0) {
            if (tknAddr != ethAddr) {
                CTokenInterface ctknContract = CTokenInterface(ctknAddr);
                ERC20Interface tknContract = ERC20Interface(tknAddr);
                uint tknBal = tknContract.balanceOf(address(this));
                assert(tknBal >= tknAmt);
                assert(ctknContract.mint(tknAmt) == 0);
            } else {
                CETHInterface cEthContract = CETHInterface(ctknAddr);
                uint tknBal = address(this).balance;
                assert(tknBal >= tknAmt);
                cEthContract.mint.value(tknAmt)();
            }
        }
    }

    function borrowTknAndTransfer(address tknAddr, address ctknAddr, uint tknAmt) public isUserWallet {
        if (tknAmt > 0) {
            CTokenInterface ctknContract = CTokenInterface(ctknAddr);
            if (tknAddr != ethAddr) {
                ERC20Interface tknContract = ERC20Interface(tknAddr);
                uint initialTknBal = tknContract.balanceOf(address(this));
                assert(ctknContract.borrow(tknAmt) == 0);
                uint finalTknBal = tknContract.balanceOf(address(this));
                assert(initialTknBal != finalTknBal);
                assert(tknContract.transfer(msg.sender, tknAmt));
            } else {
                uint initialTknBal = address(this).balance;
                assert(ctknContract.borrow(tknAmt) == 0);
                uint finalTknBal = address(this).balance;
                assert(initialTknBal != finalTknBal);
                msg.sender.transfer(tknAmt);
            }
        }
    }

    function payBorrowBack(address tknAddr, address ctknAddr, uint tknAmt) public payable {
        if (tknAmt > 0) {
            if (tknAddr != ethAddr) {
                CTokenInterface ctknContract = CTokenInterface(ctknAddr);
                assert(ctknContract.repayBorrow(tknAmt) == 0);
            } else {
                CETHInterface cEthContract = CETHInterface(ctknAddr);
                cEthContract.repayBorrow.value(tknAmt)();
            }
        }
    }

}
