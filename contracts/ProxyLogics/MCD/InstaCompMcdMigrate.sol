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

interface PoolInterface {
    function accessToken(address[] calldata ctknAddr, uint[] calldata tknAmt, bool isCompound) external;
    function paybackToken(address[] calldata ctknAddr, bool isCompound) external payable;
}

interface ManagerLike {
    function cdpCan(address, uint, address) external view returns (uint);
    function ilks(uint) external view returns (bytes32);
    function owns(uint) external view returns (address);
    function urns(uint) external view returns (address);
    function vat() external view returns (address);
    function open(bytes32, address) external returns (uint);
    function give(uint, address) external;
    function cdpAllow(uint, address, uint) external;
    function urnAllow(address, uint) external;
    function frob(uint, int, int) external;
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
    function drip(bytes32) external returns (uint);
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

interface InstaMcdAddress {
    function manager() external returns (address);
    function daiJoin() external returns (address);
    function jug() external returns (address);
    function ethAJoin() external returns (address);
    function migration() external returns (address payable);
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
     * @dev get cSAI Address
     */
    function getCSaiAddress() public pure returns (address csaiAddr) {
        csaiAddr = 0xF5DCe57282A584D2746FaF1593d3121Fcac444dC;
    }

    /**
     * @dev get MakerDAO MCD Address contract
     */
    function getMcdAddresses() public pure returns (address mcd) {
        mcd = 0xF23196DF1C440345DE07feFbe556a5eF0dcD29F0;
    }

    /**
     * @dev get cETH Address
     */
    function getCEthAddress() public pure returns (address cEthAddr) {
        cEthAddr = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
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
        sai = 0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359;
    }

    /**
     * @dev get Dai (Dai v2) address
     */
    function getDaiAddress() public pure returns (address dai) {
        dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    }

    /**
     * @dev get InstaDApp Liquidity Address
     */
    function getPoolAddress() public pure returns (address payable liqAddr) {
        liqAddr = 0x1564D040EC290C743F67F5cB11f3C1958B39872A;
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
        ethCol = wdiv(ethCol, ethExchangeRate) <= cEthBal ? ethCol : ethCol - 10000000000;
        ethCol = ethCol <= ethAmt ? ethCol : ethAmt; // Set Max if amount is greater than the Col user have

        daiDebt = CTokenInterface(getCSaiAddress()).borrowBalanceCurrent(address(this));
        daiDebt = daiDebt <= daiAmt ? daiDebt : daiAmt; // Set Max if amount is greater than the Debt user have
    }
}


contract McdResolver is CompoundResolver {
    function open() internal returns (uint cdp) {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        bytes32 ilk = 0x4554482d41000000000000000000000000000000000000000000000000000000;
        cdp = ManagerLike(manager).open(ilk, address(this));
    }

    function lockETH(
        uint cdp,
        uint amt
    ) internal
    {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        address ethJoin = InstaMcdAddress(getMcdAddresses()).ethAJoin();
        GemJoinLike(ethJoin).gem().deposit.value(amt)();
        GemJoinLike(ethJoin).gem().approve(address(ethJoin), amt);
        GemJoinLike(ethJoin).join(address(this), amt);

        // Locks WETH amount into the CDP
        VatLike(ManagerLike(manager).vat()).frob(
            ManagerLike(manager).ilks(cdp),
            ManagerLike(manager).urns(cdp),
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
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        address jug = InstaMcdAddress(getMcdAddresses()).jug();
        address daiJoin = InstaMcdAddress(getMcdAddresses()).daiJoin();

        address urn = ManagerLike(manager).urns(cdp);
        address vat = ManagerLike(manager).vat();
        bytes32 ilk = ManagerLike(manager).ilks(cdp);
        // Updates stability fee rate before generating new debt
        JugLike(jug).drip(ilk);

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

        ManagerLike(manager).frob(cdp, 0, dart);
        // Moves the DAI amount (balance in the vat in rad) to proxy's address
        ManagerLike(manager).move(cdp, address(this), toRad(wad));
        // Allows adapter to access to proxy's DAI balance in the vat
        if (VatLike(vat).can(address(this), address(daiJoin)) == 0) {
            VatLike(vat).hope(daiJoin);
        }
        DaiJoinLike(daiJoin).exit(address(this), wad);
    }
}


contract CompMcdResolver is McdResolver {
    function swapDaiToSai(
        uint wad                            // Amount to swap
    ) internal
    {
        address payable scdMcdMigration = InstaMcdAddress(getMcdAddresses()).migration();
        TokenInterface dai = TokenInterface(getDaiAddress());
        if (dai.allowance(address(this), scdMcdMigration) < wad) {
            dai.approve(scdMcdMigration, wad);
        }
        ScdMcdMigration(scdMcdMigration).swapDaiToSai(wad);
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
    event LogCompMcdMigrate(uint vaultId, uint eth, uint debt, bool isCompound);

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

        emit LogCompMcdMigrate(
            cdpNum,
            ethCol,
            saiDebt,
            isCompound
        );
    }
}


contract InstaCompMcdMigrate is BridgeResolver {
    function() external payable {}
}