pragma solidity ^0.5.7;

interface RegistryInterface {
    function proxies(address) external view returns (address);
}

interface UserWalletInterface {
    function owner() external view returns (address);
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
    function gem() external view returns (ERC20Interface);
    function gov() external view returns (ERC20Interface);
    function skr() external view returns (ERC20Interface);
    function sai() external view returns (ERC20Interface);
    function ink(bytes32) external view returns (uint);
    function tab(bytes32) external returns (uint);
    function rap(bytes32) external returns (uint);
    function per() external view returns (uint);
    function pep() external view returns (PepInterface);
}

interface PepInterface {
    function peek() external returns (bytes32, bool);
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

interface UniswapExchange {
    function getEthToTokenOutputPrice(uint256 tokensBought) external view returns (uint256 ethSold);
    function getTokenToEthOutputPrice(uint256 ethBought) external view returns (uint256 tokensSold);
    function tokenToTokenSwapOutput(
        uint256 tokensBought,
        uint256 maxTokensSold,
        uint256 maxEthSold,
        uint256 deadline,
        address tokenAddr
        ) external returns (uint256  tokensSold);
}

interface CTokenInterface {
    function redeem(uint redeemTokens) external returns (uint);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
    function exchangeRateCurrent() external returns (uint);
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
    function balanceOf(address) external view returns (uint);
}

interface CETHInterface {
    function mint() external payable; // For ETH
    function transfer(address, uint) external returns (bool);
}

interface CDAIInterface {
    function mint(uint mintAmount) external returns (uint); // For ERC20
    function repayBorrowBehalf(address borrower, uint repayAmount) external returns (uint);
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

}


contract Helper is DSMath {

    address public ethAddr = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public daiAddr = 0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359;
    address public registryAddr = 0xF5DCe57282A584D2746FaF1593d3121Fcac444dC;
    address public sai = 0x448a5065aeBB8E423F0896E6c5D525C040f59af3;
    address public ume = 0x448a5065aeBB8E423F0896E6c5D525C040f59af3; // Uniswap Maker Exchange
    address public ude = 0x448a5065aeBB8E423F0896E6c5D525C040f59af3; // Uniswap DAI Exchange
    address public cEth = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
    address public cDai = 0xF5DCe57282A584D2746FaF1593d3121Fcac444dC;
    mapping (address => uint) public deposited; // amount of CToken deposited

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

    modifier isUserWallet {
        address userAdd = UserWalletInterface(msg.sender).owner();
        address walletAdd = RegistryInterface(registryAddr).proxies(userAdd);
        require(walletAdd != address(0), "Not-User-Wallet");
        require(walletAdd == msg.sender, "Not-Wallet-Owner");
        _;
    }

    /**
     * @dev Redeem ETH/ERC20 and mint Compound Tokens
     * @param tokenAmt Amount of token To Redeem
     */
    function redeemUnderlying(address cErc20, uint tokenAmt) internal {
        CTokenInterface cToken = CTokenInterface(cErc20);
        uint toBurn = cToken.balanceOf(address(this));
        uint tokenToReturn = wmul(toBurn, cToken.exchangeRateCurrent());
        tokenToReturn = tokenToReturn > tokenAmt ? tokenAmt : tokenToReturn;
        require(cToken.redeemUnderlying(tokenToReturn) == 0, "something went wrong");
    }

}


contract MakerResolver is Helper {

    event LogOpen(uint cdpNum, address owner);
    event LogGive(uint cdpNum, address owner, address nextOwner);
    event LogLock(uint cdpNum, uint amtETH, uint amtPETH, address owner);
    event LogFree(uint cdpNum, uint amtETH, uint amtPETH, address owner);
    event LogDraw(uint cdpNum, uint amtDAI, address owner);
    event LogDrawSend(uint cdpNum, uint amtDAI, address to);
    event LogWipe(uint cdpNum, uint daiAmt, uint mkrFee, uint daiFee, address owner);
    event LogShut(uint cdpNum);

    function open() internal returns (uint) {
        bytes32 cup = TubInterface(sai).open();
        emit LogOpen(uint(cup), address(this));
        return uint(cup);
    }

    /**
     * @dev transfer CDP ownership
     */
    function give(uint cdpNum, address nextOwner) internal {
        TubInterface(sai).give(bytes32(cdpNum), nextOwner);
    }

    function wipe(uint cdpNum, uint _wad) internal returns (uint daiAmt) {
        if (_wad > 0) {
            TubInterface tub = TubInterface(sai);
            UniswapExchange daiEx = UniswapExchange(ude);
            UniswapExchange mkrEx = UniswapExchange(ume);
            ERC20Interface dai = tub.sai();
            ERC20Interface mkr = tub.gov();

            bytes32 cup = bytes32(cdpNum);

            (address lad,,,) = tub.cups(cup);
            require(lad == address(this), "cup-not-owned");

            setAllowance(dai, sai);
            setAllowance(mkr, sai);
            setAllowance(dai, ude);

            (bytes32 val, bool ok) = tub.pep().peek();

            // MKR required for wipe = Stability fees accrued in Dai / MKRUSD value
            uint mkrFee = wdiv(rmul(_wad, rdiv(tub.rap(cup), tub.tab(cup))), uint(val));

            uint daiFeeAmt = daiEx.getTokenToEthOutputPrice(mkrEx.getEthToTokenOutputPrice(mkrFee));
            daiAmt = add(_wad, daiFeeAmt);

            redeemUnderlying(cDai, daiAmt);

            if (ok && val != 0) {
                daiEx.tokenToTokenSwapOutput(
                    mkrFee,
                    daiAmt,
                    uint(999000000000000000000),
                    uint(1899063809), // 6th March 2030 GMT // no logic
                    address(mkr)
                );
            }

            tub.wipe(cup, _wad);

            emit LogWipe(
                cdpNum,
                daiAmt,
                mkrFee,
                daiFeeAmt,
                address(this)
            );

        }
    }

    function free(uint cdpNum, uint jam) internal {
        if (jam > 0) {
            bytes32 cup = bytes32(cdpNum);
            address tubAddr = sai;

            TubInterface tub = TubInterface(tubAddr);
            ERC20Interface peth = tub.skr();
            ERC20Interface weth = tub.gem();

            uint ink = rdiv(jam, tub.per());
            ink = rmul(ink, tub.per()) <= jam ? ink : ink - 1;
            tub.free(cup, ink);

            setAllowance(peth, tubAddr);


            tub.exit(ink);
            uint freeJam = weth.balanceOf(address(this)); // withdraw possible previous stuck WETH as well
            weth.withdraw(freeJam);

            emit LogFree(
                cdpNum,
                freeJam,
                ink,
                address(this)
            );
        }
    }

    function lock(uint cdpNum, uint ethAmt) internal {
        if (msg.value > 0) {
            bytes32 cup = bytes32(cdpNum);
            address tubAddr = sai;

            TubInterface tub = TubInterface(tubAddr);
            ERC20Interface weth = tub.gem();
            ERC20Interface peth = tub.skr();

            (address lad,,,) = tub.cups(cup);
            require(lad == address(this), "cup-not-owned");

            weth.deposit.value(ethAmt)();

            uint ink = rdiv(ethAmt, tub.per());
            ink = rmul(ink, tub.per()) <= ethAmt ? ink : ink - 1;

            setAllowance(weth, tubAddr);
            tub.join(ink);

            setAllowance(peth, tubAddr);
            tub.lock(cup, ink);

            emit LogLock(
                cdpNum,
                ethAmt,
                ink,
                address(this)
            );
        }
    }

    function draw(uint cdpNum, uint _wad) internal {
        bytes32 cup = bytes32(cdpNum);
        if (_wad > 0) {
            TubInterface tub = TubInterface(sai);

            tub.draw(cup, _wad);

            emit LogDraw(cdpNum, _wad, address(this));
        }
    }

    function wipeAndFree(uint cdpNum, uint jam, uint _wad) internal returns (uint daiAmt) {
        daiAmt = wipe(cdpNum, _wad);
        free(cdpNum, jam);
    }

    function lockAndDraw(uint cdpNum, uint jam, uint _wad) internal {
        lock(cdpNum, jam);
        draw(cdpNum, _wad);
    }

}


contract CompoundResolver is MakerResolver {

    event LogMint(address erc20, address cErc20, uint tokenAmt, address owner);
    event LogRedeem(address erc20, address cErc20, uint tokenAmt, address owner);
    event LogBorrow(address erc20, address cErc20, uint tokenAmt, address owner);
    event LogRepay(address erc20, address cErc20, uint tokenAmt, address owner);

    /**
     * @dev Deposit ETH/ERC20 and mint Compound Tokens
     */
    function mintCETH(uint tokenAmt) internal {
        CETHInterface cToken = CETHInterface(cEth);
        cToken.mint.value(tokenAmt)();
        uint cEthToReturn = wdiv(tokenAmt, CTokenInterface(cEth).exchangeRateCurrent());
        cToken.transfer(msg.sender, cEthToReturn);
        emit LogMint(
            ethAddr,
            cEth,
            tokenAmt,
            msg.sender
        );
    }

    /**
     * @dev Deposit ETH/ERC20 and mint Compound Tokens
     */
    function mintCDAI(uint tokenAmt) internal {
        ERC20Interface token = ERC20Interface(daiAddr);
        uint toDeposit = token.balanceOf(msg.sender);
        toDeposit = toDeposit > tokenAmt ? tokenAmt : toDeposit;
        token.transferFrom(msg.sender, address(this), toDeposit);
        CDAIInterface cToken = CDAIInterface(cDai);
        assert(cToken.mint(toDeposit) == 0);
        emit LogMint(
            daiAddr,
            cDai,
            tokenAmt,
            msg.sender
        );
    }

    function takeCETH(uint ethAmt) internal {
        CTokenInterface cToken = CTokenInterface(cEth);
        uint cTokenAmt = wdiv(ethAmt, cToken.exchangeRateCurrent());
        uint cEthBal = cToken.balanceOf(msg.sender);
        cTokenAmt = cEthBal > cTokenAmt ? cTokenAmt : cTokenAmt - 1;
        require(ERC20Interface(cEth).transferFrom(msg.sender, address(this), cTokenAmt), "Contract Approved?");
    }

}


contract Bridge is CompoundResolver {

    function payUsersDebt(uint daiDebt) internal {
        redeemUnderlying(cDai, daiDebt);
        require(CDAIInterface(cDai).repayBorrowBehalf(msg.sender, daiDebt) == 0, "Enough DAI?");
    }

    function takeDebtBack(uint daiDebt) external {
        require(ERC20Interface(daiAddr).transferFrom(msg.sender, address(this),daiDebt), "Contract Approved?");
        mintCDAI(daiDebt);
    }

    function makerToCompound(uint cdpId, uint ethCol, uint daiDebt) public payable isUserWallet returns (uint daiAmt) {
        daiAmt = wipeAndFree(cdpId, ethCol, daiDebt);
        mintCETH(ethCol);
        give(cdpId, msg.sender);
    }

    function compoundToMaker(uint cdpId, uint ethCol, uint daiDebt) public payable isUserWallet {
        payUsersDebt(daiDebt);
        takeCETH(ethCol);
        redeemUnderlying(cEth, ethCol);
        uint cdpNum = cdpId > 0 ? cdpId : open();
        lockAndDraw(cdpNum, ethCol, daiDebt);
        mintCDAI(daiDebt);
        give(cdpNum, msg.sender);
    }

}


contract MakerCompBridge is Bridge {

    uint public version;

    /**
     * @dev setting up variables on deployment
     * 1...2...3 versioning in each subsequent deployments
     */
    constructor(uint _version) public {
        setApproval(daiAddr, 10**30, cDai);
        setApproval(cDai, 10**30, cDai);
        setApproval(cEth, 10**30, cEth);
        version = _version;
    }

    function() external payable {}

}