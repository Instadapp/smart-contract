pragma solidity ^0.5.8;

interface RegistryInterface {
    function proxies(address) external view returns (address);
}

interface UserWalletInterface {
    function owner() external view returns (address);
}

interface CTokenInterface {
    function mint(uint mintAmount) external returns (uint); // For ERC20
    function redeem(uint redeemTokens) external returns (uint);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
    function borrow(uint borrowAmount) external returns (uint);
    function repayBorrowBehalf(address borrower, uint repayAmount) external returns (uint); // For ERC20
    function borrowBalanceCurrent(address account) external returns (uint);

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
    function accessToken(uint useLiqFrom, address[] calldata ctknAddr, uint[] calldata tknAmt) external;
    function paybackToken(uint useLiqFrom, address[] calldata ctknAddr) external payable;
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

    address ethAddr = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public registry = 0x498b3BfaBE9F73db90D252bCD4Fa9548Cd0Fd981;
    address public comptrollerAddr = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;

    address payable public liquidityAddr = 0x8179d350fFFc69A8b256e781ADDE8A1bb915766E;

    address public cEthAddr = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;

    function enterMarket(address cErc20) internal {
        ComptrollerInterface troller = ComptrollerInterface(comptrollerAddr);
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

    function enteredMarkets() internal view returns (address[] memory) {
        ComptrollerInterface troller = ComptrollerInterface(comptrollerAddr);
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
            erc20Contract.approve(to, uint(-1));
        }
    }

    /**
     * FOR SECURITY PURPOSE
     * only InstaDApp smart wallets can access the liquidity pool contract
     */
    modifier isUserWallet {
        address userAdd = UserWalletInterface(msg.sender).owner();
        address walletAdd = RegistryInterface(registry).proxies(userAdd);
        require(walletAdd != address(0), "not-user-wallet");
        require(walletAdd == msg.sender, "not-wallet-owner");
        _;
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
    event LogCompoundImport(address owner, uint percentage);

    function importAssets(uint toConvert) external isUserWallet {
        uint initBal = liquidityAddr.balance;
        address[] memory markets = enteredMarkets();
        BorrowData[] memory borrowArr;
        // SupplyData[] memory supplyArr;
        address[] memory borrowAddr;
        uint[] memory borrowAmt;

        // create an array of borrowed addr and amount
        for (uint i = 0; i < markets.length; i++) {
            address cErc20 = markets[i];
            uint toPayback = CTokenInterface(cErc20).borrowBalanceCurrent(msg.sender);
            toPayback = wmul(toPayback, toConvert);
            if (toPayback > 0) {
                borrowAddr[borrowAddr.length] = cErc20;
                borrowAmt[borrowAmt.length] = toPayback;
                borrowArr[borrowArr.length] = (BorrowData(cErc20,toPayback));
            }
        }

        // Get liquidity to payback borrowed assets
        LiquidityInterface(liquidityAddr).accessToken(1, borrowAddr, borrowAmt);

        // payback borrowed assets
        for (uint i = 0; i < borrowArr.length; i++) {
            address cErc20 = borrowArr[i].cAddr;
            uint toPayback = borrowArr[i].borrowAmt;
            if (cErc20 == cEthAddr) {
                CETHInterface(cErc20).repayBorrowBehalf.value(toPayback)(msg.sender);
            } else {
                CTokenInterface ctknContract = CTokenInterface(cErc20);
                address erc20 = ctknContract.underlying();
                setApproval(erc20, toPayback, cErc20);
                require(ctknContract.repayBorrowBehalf(msg.sender, toPayback) == 0, "transfer approved?");
            }
        }

        // transfer minted ctokens to InstaDApp smart wallet
        for (uint i = 0; i < markets.length; i++) {
            address cErc20 = markets[i];
            CTokenInterface ctknContract = CTokenInterface(cErc20);
            uint supplyAmt = ctknContract.balanceOf(msg.sender);
            supplyAmt = wmul(supplyAmt, toConvert);
            if (supplyAmt > 0) {
                require(ctknContract.transferFrom(msg.sender, address(this), supplyAmt), "Allowance?");
                // supplyArr[supplyArr.length] = (SupplyData(cErc20,supplyAmt));
            }
        }

        //borrow assets to payback liquidity
        for (uint i = 0; i < borrowArr.length; i++) {
            address cErc20 = borrowArr[i].cAddr;
            uint toBorrow = borrowArr[i].borrowAmt;
            CTokenInterface ctknContract = CTokenInterface(cErc20);
            address erc20 = ctknContract.underlying();
            enterMarket(cErc20);
            require(CTokenInterface(cErc20).borrow(toBorrow) == 0, "got collateral?");
            if (cErc20 == cEthAddr) {
                liquidityAddr.transfer(toBorrow);
            } else {
                setApproval(erc20, toBorrow, liquidityAddr);
                require(ERC20Interface(erc20).transfer(liquidityAddr, toBorrow), "Not-enough-amt");
            }
        }

        //payback InstaDApp liquidity
        LiquidityInterface(liquidityAddr).paybackToken(1,borrowAddr);
        assert(liquidityAddr.balance == initBal);

        emit LogCompoundImport(msg.sender, toConvert);
    }

}


contract InstaCompImport is ImportResolver {
    function() external payable {}
}