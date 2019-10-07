pragma solidity ^0.5.7;

interface CTokenInterface {
    function mint(uint mintAmount) external returns (uint); // For ERC20
    function redeem(uint redeemTokens) external returns (uint);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
    function borrow(uint borrowAmount) external returns (uint);
    function repayBorrowBehalf(address borrower, uint repayAmount) external returns (uint); // For ERC20
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
    function underlying() external view returns (address);
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

interface LiquidityInterface {
    function borrowTknAndTransfer(address ctknAddr, uint tknAmt) external;
    function payBorrowBack(address ctknAddr, uint tknAmt) external payable;
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
     * @dev get ethereum address for trade
     */
    function getAddressCETH() public pure returns (address eth) {
        eth = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
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
     * @dev get InstaDApp Liquidity contract
     */
    function getLiquidityAddr() public pure returns (address liquidity) {
        liquidity = 0x7281Db02c62e2966d5Cd20504B7C4C6eF4bD48E1;
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

    function enteredMarket() internal view returns (address[] memory) {
        ComptrollerInterface troller = ComptrollerInterface(getComptrollerAddress());
        address[] memory markets = troller.getAssetsIn(address(this));
        return markets;
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

    struct BorrowData {
        address cAddr;  // address of cToken
        uint256 borrowAmt; //amount to be pay back
    }

    struct SupplyData {
        address cAddr;  // address of cToken
        uint256 supplyAmt; //supplied amount
    }
}


contract ImportResolver is Helpers {

    function importAssets(uint toConvert) public {
        address[] memory markets = enteredMarket();
        BorrowData[] memory borrowArr;
        SupplyData[] memory supplyArr;
        for (uint i = 0; i < markets.length; i++) {
            address cErc20 = markets[i];
            CTokenInterface ctknContract = CTokenInterface(cErc20);
            address erc20 = ctknContract.underlying();
            uint toPayback = ctknContract.borrowBalanceCurrent(msg.sender);
            toPayback = wmul(toPayback, toConvert);
            if (toPayback > 0) {
                LiquidityInterface(getLiquidityAddr()).borrowTknAndTransfer(cErc20,toPayback);
                borrowArr[borrowArr.length] = (BorrowData(cErc20,toPayback));
                if (cErc20 == getAddressCETH()) {
                    CETHInterface cethToken = CETHInterface(cErc20);
                    cethToken.repayBorrowBehalf.value(toPayback)(msg.sender);
                } else {
                    setApproval(erc20, toPayback, cErc20);
                    require(ctknContract.repayBorrowBehalf(msg.sender, toPayback) == 0, "transfer approved?");
                }
            }
        }

        for (uint i = 0; i < markets.length; i++) {
            address cErc20 = markets[i];
            CTokenInterface ctknContract = CTokenInterface(cErc20);
            // address erc20 = ctknContract.underlying();
            uint supplyAmt = ctknContract.balanceOf(msg.sender);
            supplyAmt = wmul(supplyAmt, toConvert);
            if (supplyAmt > 0) {
                require(ctknContract.transferFrom(msg.sender, address(this), supplyAmt), "Allowance?");
                supplyArr[supplyArr.length] = (SupplyData(cErc20,supplyAmt));
            }
        }


        for (uint i = 0; i < borrowArr.length; i++) {
            address cErc20 = borrowArr[i].cAddr;
            CTokenInterface ctknContract = CTokenInterface(cErc20);
            address erc20 = ctknContract.underlying();
            uint toBorrow = borrowArr[i].borrowAmt;
            enterMarket(cErc20);
            require(CTokenInterface(cErc20).borrow(toBorrow) == 0, "got collateral?");
            if (cErc20 == getAddressCETH()) {
                LiquidityInterface(getLiquidityAddr()).payBorrowBack.value(toBorrow)(cErc20, toBorrow);
            } else {
                setApproval(erc20, toBorrow, getLiquidityAddr());
                require(ERC20Interface(erc20).transfer(getLiquidityAddr(), toBorrow), "Not-enough-amt");
                LiquidityInterface(getLiquidityAddr()).payBorrowBack(cErc20, toBorrow);
            }
            assert(ctknContract.borrowBalanceCurrent(getLiquidityAddr()) == 0);
        }

    }

}


contract InstaCompImport is ImportResolver {

    function() external payable {}
}