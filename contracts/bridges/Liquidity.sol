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
}

interface CTokenInterface {
    function mint(uint mintAmount) external returns (uint); // For ERC20
    function redeem(uint redeemTokens) external returns (uint);
    function borrow(uint borrowAmount) external returns (uint);
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
    function repayBorrow(uint repayAmount) external returns (uint); // For ERC20
    function underlying() external view returns (address);
}

interface CETHInterface {
    function mint() external payable; // For ETH
    function repayBorrow() external payable; // For ETH
    function transfer(address, uint) external returns (bool);
}

interface ComptrollerInterface {
    function enterMarkets(address[] calldata cTokens) external returns (uint[] memory);
    function exitMarket(address cTokenAddress) external returns (uint);
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

    address public ethAddr = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public daiAddr = 0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359;
    address public usdcAddr = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public registry = 0x498b3BfaBE9F73db90D252bCD4Fa9548Cd0Fd981;
    address public comptrollerAddr = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;

    address payable public adminOne = 0xd8db02A498E9AFbf4A32BC006DC1940495b4e592;
    address payable public adminTwo = 0x0f0EBD0d7672362D11e0b6d219abA30b0588954E;

    address public cEth = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
    address public cDai = 0xF5DCe57282A584D2746FaF1593d3121Fcac444dC;
    address public cUsdc = 0x39AA39c021dfbaE8faC545936693aC917d5E7563;

}


contract ProvideLiquidity is Helper {

    /**
     * @dev user's address => CToken Address => CToken Amount Deposited
     */
    mapping (address => mapping (address => uint)) public deposits;

    event LogDepositCToken(address user, address ctknAddr, uint amt);
    event LogWithdrawCToken(address user, address ctknAddr, uint amt);

    /**
     * @dev Deposit CToken for liquidity
     */
    function depositCTkn(address ctknAddr, uint amt) public {
        require(CTokenInterface(ctknAddr).transferFrom(msg.sender, address(this), amt), "Nothing to deposit");
        deposits[msg.sender][ctknAddr] += amt;
        emit LogDepositCToken(msg.sender, ctknAddr, amt);
    }

    /**
     * @dev Withdraw CToken from liquidity
     */
    function withdrawCTkn(address ctknAddr, uint amt) public returns(uint withdrawAmt) {
        require(deposits[msg.sender][ctknAddr] != 0, "Nothing to Withdraw");
        withdrawAmt = amt < deposits[msg.sender][ctknAddr] ? amt : deposits[msg.sender][ctknAddr];
        assert(CTokenInterface(ctknAddr).transfer(msg.sender, withdrawAmt));
        deposits[msg.sender][ctknAddr] -= withdrawAmt;
        emit LogWithdrawCToken(msg.sender, ctknAddr, withdrawAmt);
    }

}


contract AccessLiquidity is ProvideLiquidity {

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
     * @dev Borrow token and use them on InstaDApp's contract wallets
     */
    function borrowTknAndTransfer(address ctknAddr, uint tknAmt) public isUserWallet {
        if (tknAmt > 0) {
            CTokenInterface ctknContract = CTokenInterface(ctknAddr);
            if (ctknAddr != cEth) {
                address tknAddr = ctknContract.underlying();
                assert(ctknContract.borrow(tknAmt) == 0);
                assert(ERC20Interface(tknAddr).transfer(msg.sender, tknAmt));
                emit LogBorrowTknAndTransfer(tknAddr, ctknAddr, tknAmt);
            } else {
                assert(ctknContract.borrow(tknAmt) == 0);
                msg.sender.transfer(tknAmt);
                emit LogBorrowTknAndTransfer(ethAddr, ctknAddr, tknAmt);
            }
        }
    }

    /**
     * @dev Payback borrowed token and from InstaDApp's contract wallets
     */
    function payBorrowBack(address ctknAddr, uint tknAmt) public payable isUserWallet {
        if (tknAmt > 0) {
            if (ctknAddr != cEth) {
                CTokenInterface ctknContract = CTokenInterface(ctknAddr);
                address tknAddr = ctknContract.underlying();
                assert(ctknContract.repayBorrow(tknAmt) == 0);
                emit LogPayBorrowBack(tknAddr, ctknAddr, tknAmt);
            } else {
                CETHInterface cEthContract = CETHInterface(ctknAddr);
                cEthContract.repayBorrow.value(tknAmt);
                emit LogPayBorrowBack(ethAddr, ctknAddr, tknAmt);
            }
        }
    }

}


contract AdminStuff is AccessLiquidity {

    modifier isAdmin {
        require(msg.sender == adminOne || msg.sender == adminTwo, "Not admin address");
        _;
    }

    /**
     * Give approval to other addresses
     */
    function setApproval(address erc20, address to) public isAdmin {
        ERC20Interface(erc20).approve(to, uint(-1));
    }

    /**
     * (HIGHLY UNLIKELY TO HAPPEN)
     * collecting ETH if this contract has it
     */
    function collectEth() public isAdmin {
        msg.sender.transfer(address(this).balance);
    }

    /**
     * Enter Compound Market to enable borrowing
     */
    function enterMarket(address[] memory cTknAddrArr) public isAdmin {
        ComptrollerInterface troller = ComptrollerInterface(comptrollerAddr);
        troller.enterMarkets(cTknAddrArr);
    }

    /**
     * Enter Compound Market to disable borrowing
     */
    function exitMarket(address cErc20) public isAdmin {
        ComptrollerInterface troller = ComptrollerInterface(comptrollerAddr);
        troller.exitMarket(cErc20);
    }

}


contract Liquidity is AdminStuff {

    /**
     * @dev setting up all required token approvals
     */
    constructor() public {
        ERC20Interface(daiAddr).approve(cDai, uint(-1));
        ERC20Interface(usdcAddr).approve(cUsdc, uint(-1));
        ERC20Interface(cDai).approve(cDai, uint(-1));
        ERC20Interface(cUsdc).approve(cUsdc, uint(-1));
        ERC20Interface(cEth).approve(cEth, uint(-1));
    }

    function() external payable {}

}