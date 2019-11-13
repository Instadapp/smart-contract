pragma solidity ^0.5.8;

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
    function transferFrom(address, address, uint) external returns (bool);
    function deposit() external payable;
    function withdraw(uint) external;
}

interface CTokenInterface {
    function mint(uint mintAmount) external returns (uint);
    function redeem(uint redeemTokens) external returns (uint);
    function borrow(uint borrowAmount) external returns (uint);
    function borrowBalanceCurrent(address account) external returns (uint);
    function repayBorrow(uint repayAmount) external returns (uint);
    function totalReserves() external view returns (uint);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
    function underlying() external view returns (address);
    function exchangeRateCurrent() external returns (uint);

    function balanceOf(address owner) external view returns (uint256 balance);
    function allowance(address, address) external view returns (uint);
    function approve(address, uint) external;
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
}

interface PepInterface {
    function peek() external returns (bytes32, bool);
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
    function ethToTokenSwapOutput(uint256 tokensBought, uint256 deadline) external payable returns (uint256  ethSold);
}

interface UniswapFactoryInterface {
    function getExchange(address token) external view returns (address exchange);
}

interface MCDInterface {
    function swapDaiToSai(uint wad) external;
    function migrate(bytes32 cup) external returns (uint cdp);
}

interface PoolInterface {
    function accessToken(address[] calldata ctknAddr, uint[] calldata tknAmt, bool isCompound) external;
    function paybackToken(address[] calldata ctknAddr, bool isCompound) external payable;
}

interface OtcInterface {
    function getPayAmount(address, address, uint) external view returns (uint);
    function buyAllAmount(
        address,
        uint,
        address,
        uint
    ) external;
}

interface ManagerLike {
    function cdpCan(address, uint, address) external view returns (uint);
    function ilks(uint) external view returns (bytes32);
    function owns(uint) external view returns (address);
    function urns(uint) external view returns (address);
    function vat() external view returns (address);
    function open(bytes32) external returns (uint);
    function give(uint, address) external;
    function cdpAllow(uint, address, uint) external;
    function urnAllow(address, uint) external;
    function frob(uint, int, int) external;
    function frob(
        uint,
        address,
        int,
        int
    ) external;
    function flux(uint, address, uint) external;
    function move(uint, address, uint) external;
    function exit(
        address,
        uint,
        address,
        uint
    ) external;
    function quit(uint, address) external;
    function enter(address, uint) external;
    function shift(uint, uint) external;
}

interface GemLike {
    function approve(address, uint) external;
    function transfer(address, uint) external;
    function transferFrom(address, address, uint) external;
    function deposit() external payable;
    function withdraw(uint) external;
}

interface JugLike {
    function drip(bytes32) external;
}

interface VatLike {
    function can(address, address) external view returns (uint);
    function ilks(bytes32) external view returns (uint, uint, uint, uint, uint);
    function dai(address) external view returns (uint);
    function urns(bytes32, address) external view returns (uint, uint);
    function frob(
        bytes32,
        address,
        address,
        address,
        int,
        int
    ) external;
    function hope(address) external;
    function move(address, address, uint) external;
}

interface GemJoinLike {
    function dec() external returns (uint);
    function gem() external returns (GemLike);
    function join(address, uint) external payable;
    function exit(address, uint) external;
}

interface GNTJoinLike {
    function bags(address) external view returns (address);
    function make(address) external returns (address);
}

interface DaiJoinLike {
    function vat() external returns (VatLike);
    function dai() external returns (GemLike);
    function join(address, uint) external payable;
    function exit(address, uint) external;
}

/** Swap Functionality */
interface ScdMcdMigration {
    function swapDaiToSai(uint daiAmt) external;
    function swapSaiToDai(uint saiAmt) external;
}


contract DSMath {

    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, "math-not-safe");
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        z = x - y <= x ? x - y : 0;
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, "math-not-safe");
    }

    uint constant WAD = 10 ** 18;
    uint constant RAY = 10 ** 27;

    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), RAY / 2) / RAY;
    }

    function wmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }

    function rdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, RAY), y / 2) / y;
    }

    function wdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, WAD), y / 2) / y;
    }

    function toInt(uint x) internal pure returns (int y) {
        y = int(x);
        require(y >= 0, "int-overflow");
    }

    function toRad(uint wad) internal pure returns (uint rad) {
        rad = mul(wad, 10 ** 27);
    }

}


contract Helpers is DSMath {

    /**
     * @dev get Compound Comptroller Address
     */
    function getCSaiAddress() public pure returns (address csaiAddr) {
        csaiAddr = 0xF5DCe57282A584D2746FaF1593d3121Fcac444dC;
    }

    /**
     * @dev get Compound Comptroller Address
     */
    function getCEthAddress() public pure returns (address cEthAddr) {
        cEthAddr = 0xF5DCe57282A584D2746FaF1593d3121Fcac444dC; // Check
    }

    /**
     * @dev get Compound Comptroller Address
     */
    function getCDaiAddress() public pure returns (address cdaiAddr) {
        cdaiAddr = 0xF5DCe57282A584D2746FaF1593d3121Fcac444dC; // Check
    }

    /**
     * @dev get MakerDAO SCD CDP engine
     */
    function getSaiTubAddress() public pure returns (address sai) {
        sai = 0x448a5065aeBB8E423F0896E6c5D525C040f59af3;
    }

    /**
     * @dev get Sai (Dai v1) address
     */
    function getSaiAddress() public pure returns (address sai) {
        sai = 0x448a5065aeBB8E423F0896E6c5D525C040f59af3;
    }

    /**
     * @dev get Dai (Dai v2) address
     */
    function getDaiAddress() public pure returns (address dai) {
        dai = 0x1D7e3a1A65a367db1D1D3F51A54aC01a2c4C92ff;
    }

    /**
     * @dev get Compound WETH Address
     */
    function getWETHAddress() public pure returns (address wethAddr) {
        wethAddr = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // main
    }

    /**
     * @dev get OTC Address
     */
    function getOtcAddress() public pure returns (address otcAddr) {
        otcAddr = 0x39755357759cE0d7f32dC8dC45414CCa409AE24e; // main
    }

    /**
     * @dev get uniswap MKR exchange
     */
    function getUniswapMKRExchange() public pure returns (address ume) {
        ume = 0x2C4Bd064b998838076fa341A83d007FC2FA50957;
    }

    /**
     * @dev get uniswap factory
     */
    function getUniswapFactory() public pure returns (address addr) {
        addr = 0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95;
    }

    /**
     * @dev get InstaDApp Liquidity Address
     */
    function getPoolAddress() public pure returns (address payable liqAddr) {
        liqAddr = 0x1564D040EC290C743F67F5cB11f3C1958B39872A;
    }

    /**
     * @dev get InstaDApp CDP's Address
     */
    function getGiveAddress() public pure returns (address addr) {
        addr = 0xc679857761beE860f5Ec4B3368dFE9752580B096;
    }

    function getManagerAddress() public pure returns (address managerAddr) {
        managerAddr = 0xb1fd1f2c83A6cb5155866169D81a9b7cF9e2019D;
    }

    function getMigrateAddress() public pure returns (address migrateAddr) {
        migrateAddr = 0xb1fd1f2c83A6cb5155866169D81a9b7cF9e2019D;
    }

    function getdaiJoinAddress() public pure returns (address daiJoinAddr) {
        daiJoinAddr = 0x9E0d5a6a836a6C323Cf45Eb07Cb40CFc81664eec; //Check
    }

    function getsaiJoinAddress() public pure returns (address saiJoinAddr) {
        saiJoinAddr = 0xfe85Da396c78f698ec894bc90deC7d6F44cAA76C; //Check
    }

    function getEthJoinAddress() public pure returns (address ethJoinAddr) {
        ethJoinAddr = 0x55cD2f4cF74eDc7c869BcF5e16086781eE97EE40; //Check
    }

    function getVatAddress() public pure returns (address vat) {
        vat = 0xb597803e4B5b2A43A92F3e1DCaFEA5425c873116;
    }

    function getSpotAddress() public pure returns (address spot) {
        spot = 0x932E82e999Fad1f7Ea9566f42cd3E94a4F46897E;
    }

    function getJugAddress() public pure returns (address jug) {
        jug = 0x9404A7Fd173f1AA716416f391ACCD28Bd0d84406;
    }

    /**
     * @dev setting allowance if required
     */
    function setApproval(address erc20, uint srcAmt, address to) internal {
        TokenInterface erc20Contract = TokenInterface(erc20);
        uint tokenAllowance = erc20Contract.allowance(address(this), to);
        if (srcAmt > tokenAllowance) {
            erc20Contract.approve(to, uint(-1));
        }
    }

}


contract LiquidityResolver is Helpers {
    //Had to write seprate for pool, remix was showing error.
    function getLiquidity(uint _wad, bool isComp) internal {
        uint[] memory _wadArr = new uint[](1);
        _wadArr[0] = _wad;

        address[] memory addrArr = new address[](1);
        addrArr[0] = getSaiAddress();

        // Get liquidity assets to payback user wallet borrowed assets
        PoolInterface(getPoolAddress()).accessToken(addrArr, _wadArr, isComp);
    }

    function paybackLiquidity(uint _wad, bool isComp) internal {
        address[] memory addrArr = new address[](1);
        addrArr[0] = getSaiAddress();

        // transfer and payback dai to InstaDApp pool.
        require(TokenInterface(getSaiAddress()).transfer(getPoolAddress(), _wad), "Not-enough-dai");
        PoolInterface(getPoolAddress()).paybackToken(addrArr, isComp);
    }
}


contract CompoundResolver is LiquidityResolver {
    /**
     * @dev Redeem ETH/ERC20 and mint Compound Tokens
     * @param tokenAmt Amount of token To Redeem
     */
    function redeemCEthUnderlying(uint tokenAmt) internal {
        address cErc20 = getCEthAddress();
        CTokenInterface cToken = CTokenInterface(cErc20);
        setApproval(cErc20, tokenAmt, cErc20);
        require(cToken.redeemUnderlying(tokenAmt) == 0, "something went wrong");
    }

    /**
     * @dev Pay Debt ETH/ERC20
     */
    function repaySaiToken(uint tokenAmt) internal {
        CTokenInterface cToken = CTokenInterface(getCSaiAddress());
        address erc20 = cToken.underlying();
        setApproval(erc20, tokenAmt, getCSaiAddress());
        require(cToken.repayBorrow(tokenAmt) == 0, "transfer approved?");
    }

    /**
     * @dev Check if entered amt is valid or not (Used in makerToCompound)
     */
    function checkCompound(uint ethAmt, uint daiAmt) internal returns (uint ethCol, uint daiDebt) {
        CTokenInterface cEthContract = CTokenInterface(getCEthAddress());
        uint cEthBal = cEthContract.balanceOf(address(this));
        uint ethExchangeRate = cEthContract.exchangeRateCurrent();
        ethCol = wmul(cEthBal, ethExchangeRate);
        // ethCol = wdiv(ethCol, ethExchangeRate) <= cEthBal ? ethCol : ethCol - 1; //Check Thrilok - why?
        ethCol = ethCol <= ethAmt ? ethCol : ethAmt; // Set Max if amount is greater than the Col user have

        daiDebt = CTokenInterface(getCSaiAddress()).borrowBalanceCurrent(address(this));
        daiDebt = daiDebt <= daiAmt ? daiDebt : daiAmt; // Set Max if amount is greater than the Debt user have
    }
}


contract McdResolver is CompoundResolver {
    function open() internal returns (uint cdp) {
        bytes32 ilk = 0x4554482d41000000000000000000000000000000000000000000000000000000;
        cdp = ManagerLike(getManagerAddress()).open(ilk);
    }

    function lockETH(
        uint cdp,
        uint amt
    ) internal
    {
        GemJoinLike(getEthJoinAddress()).gem().deposit.value(amt)();
        GemJoinLike(getEthJoinAddress()).gem().approve(address(getEthJoinAddress()), amt);
        GemJoinLike(getEthJoinAddress()).join(address(this), amt);

        // Locks WETH amount into the CDP
        VatLike(ManagerLike(getManagerAddress()).vat()).frob(
            ManagerLike(getManagerAddress()).ilks(cdp),
            ManagerLike(getManagerAddress()).urns(cdp),
            address(this),
            address(this),
            int(amt),
            0
        );
    }

    function draw(
        uint cdp,
        uint wad
    ) internal
    {
        address urn = ManagerLike(getManagerAddress()).urns(cdp);
        address vat = ManagerLike(getManagerAddress()).vat();
        bytes32 ilk = ManagerLike(getManagerAddress()).ilks(cdp);
        // Updates stability fee rate before generating new debt
        JugLike(getJugAddress()).drip(ilk);

        int dart;
        // Gets actual rate from the vat
        (, uint rate,,,) = VatLike(vat).ilks(ilk);
        // Gets DAI balance of the urn in the vat
        uint dai = VatLike(vat).dai(urn);

        // If there was already enough DAI in the vat balance, just exits it without adding more debt
        if (dai < mul(wad, RAY)) {
            // Calculates the needed dart so together with the existing dai in the vat is enough to exit wad amount of DAI tokens
            dart = int(sub(mul(wad, RAY), dai) / rate);
            // This is neeeded due lack of precision. It might need to sum an extra dart wei (for the given DAI wad amount)
            dart = mul(uint(dart), rate) < mul(wad, RAY) ? dart + 1 : dart;
        }

        ManagerLike(getManagerAddress()).frob(cdp, 0, dart);
        // Moves the DAI amount (balance in the vat in rad) to proxy's address
        ManagerLike(getManagerAddress()).move(cdp, address(this), toRad(wad));
        // Allows adapter to access to proxy's DAI balance in the vat
        if (VatLike(vat).can(address(this), address(getdaiJoinAddress())) == 0) {
            VatLike(vat).hope(getdaiJoinAddress());
        }
        DaiJoinLike(getdaiJoinAddress()).exit(address(this), wad);
    }
}


contract CompMcdResolver is McdResolver {
    function swapDaiToSai(
        uint wad                            // Amount to swap
    ) internal
    {
        TokenInterface sai = TokenInterface(getSaiAddress());
        TokenInterface dai = TokenInterface(getDaiAddress());
        if (dai.allowance(address(this), getMigrateAddress()) < wad) {
            dai.approve(getMigrateAddress(), wad);
        }
        ScdMcdMigration(getMigrateAddress()).swapDaiToSai(wad);
        sai.transfer(getPoolAddress(), wad);
    }

    function paybackAndRedeem(uint ethAmt, uint saiAmt, bool isCompound) internal {
        getLiquidity(saiAmt, isCompound);
        repaySaiToken(saiAmt);
        redeemCEthUnderlying(ethAmt);
    }

    function lockDrawSwapMcd(
        uint cdpId,
        uint ethAmt,
        uint saiAmt,
        bool isCompound
    ) internal
    {
        lockETH(cdpId,ethAmt);
        draw(cdpId, saiAmt);
        swapDaiToSai(saiAmt);
        paybackLiquidity(saiAmt, isCompound);
    }

}


contract BridgeResolver is CompMcdResolver {

    function compoundToMcdMigrate(
        uint cdpId,
        uint ethQty,
        uint saiQty,
        bool isCompound
    ) external
    {
        // subtracting 0.00000001 ETH from initialPoolBal to solve Compound 8 decimal CETH error.
        uint initialPoolBal = sub(getPoolAddress().balance, 10000000000);

        uint cdpNum = cdpId > 0 ? cdpId : open();
        (uint ethCol, uint saiDebt) = checkCompound(ethQty, saiQty);
        paybackAndRedeem(ethCol, saiDebt, isCompound); // Getting Liquidity inside Wipe function
        ethCol = ethCol < address(this).balance ? ethCol : address(this).balance;
        lockDrawSwapMcd(
            cdpNum,
            ethCol,
            saiDebt,
            isCompound
        ); // Returning Liquidity inside Borrow function

        uint finalPoolBal = getPoolAddress().balance;
        assert(finalPoolBal >= initialPoolBal);
    }
}


contract InstaCompMcdMigrate is BridgeResolver {
    function() external payable {}
}