pragma solidity ^0.5.7;

interface RegistryInterface {
    function proxies(address) external view returns (address);
}

interface UserWalletInterface {
    function owner() external view returns (address);
}

interface CTokenInterface {
    function borrow(uint borrowAmount) external returns (uint);
    function transfer(address, uint) external returns (bool);
    function repayBorrow(uint repayAmount) external returns (uint);
    function underlying() external view returns (address);
    function borrowBalanceCurrent(address account) external returns (uint);
}

interface CETHInterface {
    function balanceOf(address) external view returns (uint);
    function mint() external payable; // For ETH
    function repayBorrow() external payable; // For ETH
    function borrowBalanceCurrent(address account) external returns (uint);
    function redeem(uint redeemAmount) external returns (uint);
}

interface ComptrollerInterface {
    function enterMarkets(address[] calldata cTokens) external returns (uint[] memory);
    function exitMarket(address cTokenAddress) external returns (uint);
}

interface TubInterface {
    function open() external returns (bytes32);
    function join(uint) external;
    function exit(uint) external;
    function lock(bytes32, uint) external;
    function free(bytes32, uint) external;
    function draw(bytes32, uint) external;
    function wipe(bytes32, uint) external;
    function give(bytes32, address) external;
    function shut(bytes32) external;
    function cups(bytes32) external view returns (address, uint, uint, uint);
    function gem() external view returns (TokenInterface);
    function gov() external view returns (TokenInterface);
    function skr() external view returns (TokenInterface);
    function sai() external view returns (TokenInterface);
    function ink(bytes32) external view returns (uint);
    function tab(bytes32) external returns (uint);
    function rap(bytes32) external returns (uint);
    function per() external view returns (uint);
    function pep() external view returns (PepInterface);
}

interface TokenInterface {
    function allowance(address, address) external view returns (uint);
    function balanceOf(address) external view returns (uint);
    function approve(address, uint) external;
    function transfer(address, uint) external returns (bool);
    function deposit() external payable;
    function withdraw(uint) external;
}

interface PepInterface {
    function peek() external returns (bytes32, bool);
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

    function wdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, WAD), y / 2) / y;
    }

}


contract Helpers is DSMath {

    address public registry = 0x498b3BfaBE9F73db90D252bCD4Fa9548Cd0Fd981;
    address public comptrollerAddr = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    address public saiTubAddress = 0x448a5065aeBB8E423F0896E6c5D525C040f59af3;

    address payable public controllerOne = 0x0f0EBD0d7672362D11e0b6d219abA30b0588954E;
    address payable public controllerTwo = 0xd8db02A498E9AFbf4A32BC006DC1940495b4e592;

    address public usdcAddr = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public cEth = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
    address public cDai = 0xF5DCe57282A584D2746FaF1593d3121Fcac444dC;
    address public cUsdc = 0x39AA39c021dfbaE8faC545936693aC917d5E7563;

    bytes32 public CDPID;

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

}


contract CompoundResolver is Helpers {

    function mintAndBorrow(address[] memory cErc20, uint[] memory tknAmt) internal {
        if (cErc20.length > 0) {
            CETHInterface(cEth).mint.value(address(this).balance)();
            for (uint i = 0; i < cErc20.length; i++) {
                if (cErc20[i] != address(0)) {
                    if (tknAmt[i] > 0) {
                        CTokenInterface ctknContract = CTokenInterface(cErc20[i]);
                        if (cErc20[i] != cEth) {
                            address tknAddr = ctknContract.underlying();
                            assert(ctknContract.borrow(tknAmt[i]) == 0);
                            assert(TokenInterface(tknAddr).transfer(msg.sender, tknAmt[i]));
                        } else {
                            assert(ctknContract.borrow(tknAmt[i]) == 0);
                            msg.sender.transfer(tknAmt[i]);
                        }
                    }
                }
            }
        }
    }

    function paybackAndWithdraw(address[] memory cErc20) internal {
        if (cErc20.length > 0) {
            CETHInterface cethContract = CETHInterface(cEth);
            for (uint i = 0; i < cErc20.length; i++) {
                if (cErc20[i] != address(0)) {
                    CTokenInterface ctknContract = CTokenInterface(cErc20[i]);
                    uint tknBorrowed = ctknContract.borrowBalanceCurrent(address(this));
                    if (tknBorrowed > 0) {
                        if (cErc20[i] != cEth) {
                            assert(ctknContract.repayBorrow(tknBorrowed) == 0);
                        } else {
                            cethContract.repayBorrow.value(tknBorrowed)();
                        }
                    }
                    assert(ctknContract.borrowBalanceCurrent(address(this)) == 0);
                }
            }
            uint ethSupplied = cethContract.balanceOf(address(this));
            assert(cethContract.redeem(ethSupplied) == 0);
        }
    }
}


contract MakerResolver is CompoundResolver {

    function lockAndDraw(uint _wad) internal {
        if (_wad > 0) {
            uint ethToSupply = address(this).balance;
            bytes32 cup = CDPID;
            address tubAddr = saiTubAddress;

            TubInterface tub = TubInterface(tubAddr);
            TokenInterface weth = tub.gem();

            (address lad,,,) = tub.cups(cup);
            require(lad == address(this), "cup-not-owned");

            weth.deposit.value(ethToSupply)();

            uint ink = rdiv(ethToSupply, tub.per());
            ink = rmul(ink, tub.per()) <= ethToSupply ? ink : ink - 1;

            tub.join(ink);
            tub.lock(cup, ink);


            tub.draw(cup, _wad);
            tub.sai().transfer(msg.sender, _wad);
        }
    }

    function wipeAndFree() internal {
        TubInterface tub = TubInterface(saiTubAddress);
        TokenInterface weth = tub.gem();

        bytes32 cup = CDPID;
        uint _wad = tub.tab(cup);

        if (_wad > 0) {
            (address lad,,,) = tub.cups(cup);
            require(lad == address(this), "cup-not-owned");

            tub.wipe(cup, _wad);

            // free ETH
            uint _jam = rmul(tub.ink(cup), tub.per());
            uint ink = rdiv(_jam, tub.per());
            ink = rmul(ink, tub.per()) <= _jam ? ink : ink - 1;
            tub.free(cup, ink);

            tub.exit(ink);
            uint freeJam = weth.balanceOf(address(this)); // withdraw possible previous stuck WETH as well
            weth.withdraw(freeJam);
        }
    }
}


contract ProvideLiquidity is MakerResolver {

    /**
     * @dev user => ETH deposits
     */
    mapping (address => uint) public deposits;

    event LogDepositETH(address user, uint amt);
    event LogWithdrawETH(address user, uint amt);

    /**
     * @dev deposit ETH
     */
    function depositETH() external payable {
        deposits[msg.sender] += msg.value;
        emit LogDepositETH(msg.sender, msg.value);
    }

    /**
     * @dev withdraw ETH
     */
    function withdrawETH(uint amount) external returns (uint withdrawAmt) {
        require(deposits[msg.sender] > 0, "no-balance");
        withdrawAmt = amount < deposits[msg.sender] ? amount : deposits[msg.sender];
        msg.sender.transfer(withdrawAmt);
        deposits[msg.sender] -= withdrawAmt;
        emit LogWithdrawETH(msg.sender, withdrawAmt);
    }

}


contract AccessLiquidity is ProvideLiquidity {

    event LogLiquidityBorrow(address user, address[] ctknAddr, uint[] amount , bool isCompound);
    event LogLiquidityPayback(address user, address[] ctknAddr, bool isCompound);

    /**
     * @dev borrow token and use them on InstaDApp's contract wallets
     */
    function accessToken(address[] calldata ctknAddr, uint[] calldata tknAmt, bool isCompound) external isUserWallet {
        if (isCompound) {
            mintAndBorrow(ctknAddr, tknAmt);
        } else {
            lockAndDraw(tknAmt[0]);
        }
        emit LogLiquidityBorrow(
            msg.sender,
            ctknAddr,
            tknAmt,
            isCompound
        );
    }

    /**
     * @dev Payback borrowed token and from InstaDApp's contract wallets
     */
    function paybackToken(address[] calldata ctknAddr, bool isCompound) external payable isUserWallet {
        if (isCompound) {
            paybackAndWithdraw(ctknAddr);
        } else {
            wipeAndFree();
        }
        emit LogLiquidityPayback(msg.sender, ctknAddr, isCompound);
    }

}


contract Controllers is AccessLiquidity {

    modifier isController {
        require(msg.sender == controllerOne || msg.sender == controllerTwo, "not-controller");
        _;
    }

    /**
     * give approval to other addresses
     */
    function setApproval(address erc20, address to) external isController {
        TokenInterface(erc20).approve(to, uint(-1));
    }


    /**
     * enter compound market to enable borrowing
     */
    function enterMarket(address[] calldata cTknAddrArr) external isController {
        ComptrollerInterface troller = ComptrollerInterface(comptrollerAddr);
        troller.enterMarkets(cTknAddrArr);
    }

    /**
     * exit compound market to disable borrowing
     */
    function exitMarket(address cErc20) external isController {
        ComptrollerInterface troller = ComptrollerInterface(comptrollerAddr);
        troller.exitMarket(cErc20);
    }

}


contract InstaPool is Controllers {

    constructor() public {
        TubInterface tub = TubInterface(saiTubAddress);
        CDPID = tub.open(); // new SCD CDP
        TokenInterface weth = tub.gem();
        TokenInterface peth = tub.skr();
        TokenInterface dai = tub.sai();
        TokenInterface mkr = tub.gov();
        weth.approve(saiTubAddress, uint(-1));
        peth.approve(saiTubAddress, uint(-1));
        dai.approve(saiTubAddress, uint(-1));
        mkr.approve(saiTubAddress, uint(-1));
        dai.approve(cDai, uint(-1));
        TokenInterface(usdcAddr).approve(cUsdc, uint(-1));
        TokenInterface(cDai).approve(cDai, uint(-1));
        TokenInterface(cUsdc).approve(cUsdc, uint(-1));
        TokenInterface(cEth).approve(cEth, uint(-1));
        address[] memory enterMarketArr = new address[](3);
        enterMarketArr[0] = cEth;
        enterMarketArr[1] = cDai;
        enterMarketArr[2] = cUsdc;
        ComptrollerInterface(comptrollerAddr).enterMarkets(enterMarketArr);
    }

    function() external payable {}
}