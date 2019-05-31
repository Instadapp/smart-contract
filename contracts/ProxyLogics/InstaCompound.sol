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
    function setApproval(ERC20Interface erc20Contract, uint srcAmt, address to) internal {
        uint tokenAllowance = erc20Contract.allowance(address(this), to);
        if (srcAmt > tokenAllowance) {
            erc20Contract.approve(to, 2**255);
        }
    }

    /**
     * @dev get ethereum address for trade
     */
    function getAddressETH() public pure returns (address eth) {
        eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }

    /**
     * @dev get Compound Comptroller
     */
    function getComptrollerAddress() public pure returns (address troller) {
        troller = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
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

}


contract CompoundResolver is Helpers {

    event LogMint(address erc20, address cErc20, uint tokenAmt, address owner);
    event LogRedeem(address erc20, address cErc20, uint tokenAmt, address owner);
    event LogBorrow(address erc20, address cErc20, uint tokenAmt, address owner);
    event LogRepay(address erc20, address cErc20, uint tokenAmt, address owner);
    event LogRepayBehalf(address erc20, address cErc20, uint tokenAmt, address owner, address borrower);

    function enterMarkets(address[] calldata cTokensAdd) external returns (uint[] memory isSuccess) {
        isSuccess = ComptrollerInterface(getComptrollerAddress()).enterMarkets(cTokensAdd);
    }

    function exitMarket(address cTokensAdd) external returns (uint isSuccess) {
        isSuccess = ComptrollerInterface(getComptrollerAddress()).exitMarket(cTokensAdd);
    }

    function mintCToken(address erc20, address cErc20, uint tokenAmt) external payable {
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
            setApproval(token, toDeposit, cErc20);
            assert(cToken.mint(toDeposit) == 0);
        }
        emit LogMint(
            erc20,
            cErc20,
            tokenAmt,
            msg.sender
        );
    }

    function redeemCToken(address erc20, address cErc20, uint cTokenAmt) external {
        CTokenInterface cToken = CTokenInterface(cErc20);
        uint toBurn = cToken.balanceOf(address(this));
        if (toBurn > cTokenAmt) {
            toBurn = cTokenAmt;
        }
        setApproval(cToken, toBurn, cErc20);
        require(cToken.redeem(toBurn) == 0, "something went wrong");
        transferToken(erc20);
        uint tokenReturned = wmul(cToken.balanceOf(address(this)), cToken.exchangeRateCurrent());
        emit LogRedeem(
            erc20,
            cErc20,
            tokenReturned,
            address(this)
        );
    }

    function redeemUnderlying(address erc20, address cErc20, uint tokenAmt) external {
        CTokenInterface cToken = CTokenInterface(cErc20);
        setApproval(cToken, 10**50, cErc20);
        require(cToken.redeemUnderlying(tokenAmt) == 0, "something went wrong");
        transferToken(erc20);
        emit LogRedeem(
            erc20,
            cErc20,
            tokenAmt,
            address(this)
        );
    }

    function borrow(address erc20, address cErc20, uint tokenAmt) external {
        require(CTokenInterface(cErc20).borrow(tokenAmt) == 0, "got collateral?");
        transferToken(erc20);
        emit LogBorrow(
            erc20,
            cErc20,
            tokenAmt,
            address(this)
        );
    }

    function repayToken(address erc20, address cErc20, uint tokenAmt) external payable {
        if (erc20 == getAddressETH()) {
            CETHInterface cToken = CETHInterface(cErc20);
            cToken.repayBorrow.value(msg.value)();
        } else {
            CERC20Interface cToken = CERC20Interface(cErc20);
            ERC20Interface token = ERC20Interface(erc20);
            uint toRepay = token.balanceOf(msg.sender);
            if (toRepay > tokenAmt) {
                toRepay = tokenAmt;
            }
            setApproval(token, toRepay, cErc20);
            token.transferFrom(msg.sender, address(this), toRepay);
            require(cToken.repayBorrow(toRepay) == 0, "transfer approved?");
        }
        emit LogRepay(
            erc20,
            cErc20,
            tokenAmt,
            address(this)
        );
    }

    function repaytokenBehalf(
        address borrower,
        address erc20,
        address cErc20,
        uint tokenAmt
    ) external payable
    {
        if (erc20 == getAddressETH()) {
            CETHInterface cToken = CETHInterface(cErc20);
            cToken.repayBorrowBehalf.value(msg.value)(borrower);
        } else {
            CERC20Interface cToken = CERC20Interface(cErc20);
            ERC20Interface token = ERC20Interface(erc20);
            uint toRepay = token.balanceOf(msg.sender);
            if (toRepay > tokenAmt) {
                toRepay = tokenAmt;
            }
            setApproval(token, toRepay, cErc20);
            uint tokenAllowance = token.allowance(address(this), cErc20);
            if (toRepay > tokenAllowance) {
                token.approve(cErc20, toRepay);
            }
            token.transferFrom(msg.sender, address(this), toRepay);
            require(cToken.repayBorrowBehalf(borrower, tokenAmt) == 0, "transfer approved?");
        }
        emit LogRepay(
            erc20,
            cErc20,
            tokenAmt,
            address(this),
            borrower
        );
    }

}


contract InstaCompound is CompoundResolver {

    uint public version;

    /**
     * @dev setting up variables on deployment
     * 1...2...3 versioning in each subsequent deployments
     */
    constructor(uint _version) public {
        version = _version;
    }

}