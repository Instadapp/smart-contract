pragma solidity ^0.5.7;

interface GemLike {
    function approve(address, uint) external;
    function transfer(address, uint) external;
    function transferFrom(address, address, uint) external;
    function deposit() external payable;
    function withdraw(uint) external;
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
    function gem(bytes32, address) external view returns (uint);

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

interface HopeLike {
    function hope(address) external;
    function nope(address) external;
}

interface JugLike {
    function drip(bytes32) external returns (uint);
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

interface PepInterface {
    function peek() external returns (bytes32, bool);
}

interface MakerOracleInterface {
    function read() external view returns (bytes32);
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

interface PoolInterface {
    function accessToken(address[] calldata ctknAddr, uint[] calldata tknAmt, bool isCompound) external;
    function paybackToken(address[] calldata ctknAddr, bool isCompound) external payable;
}

interface CTokenInterface {
    function redeem(uint redeemTokens) external returns (uint);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
    function borrow(uint borrowAmount) external returns (uint);
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

interface ComptrollerInterface {
    function enterMarkets(address[] calldata cTokens) external returns (uint[] memory);
    function exitMarket(address cTokenAddress) external returns (uint);
    function getAssetsIn(address account) external view returns (address[] memory);
    function getAccountLiquidity(address account) external view returns (uint, uint, uint);
}

interface CompOracleInterface {
    function getUnderlyingPrice(address) external view returns (uint);
}

interface InstaMcdAddress {
    function manager() external view returns (address);
    function dai() external view returns (address);
    function daiJoin() external view returns (address);
    function vat() external view returns (address);
    function jug() external view returns (address);
    function ethAJoin() external view returns (address);
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


contract DSMath {

    function sub(uint x, uint y) internal pure returns (uint z) {
        z = x - y <= x ? x - y : 0;
    }

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

    function toInt(uint x) internal pure returns (int y) {
        y = int(x);
        require(y >= 0, "int-overflow");
    }

    function toRad(uint wad) internal pure returns (uint rad) {
        rad = mul(wad, 10 ** 27);
    }

}


contract Helper is DSMath {

    /**
     * @dev get ethereum address for trade
     */
    function getAddressETH() public pure returns (address eth) {
        eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }

    /**
     * @dev get MakerDAO MCD Address contract
     */
    function getMcdAddresses() public pure returns (address mcd) {
        mcd = 0xF23196DF1C440345DE07feFbe556a5eF0dcD29F0;
    }

    /**
     * @dev get InstaDApp Liquidity contract
     */
    function getPoolAddr() public pure returns (address poolAddr) {
        poolAddr = 0x1564D040EC290C743F67F5cB11f3C1958B39872A;
    }

    /**
     * @dev get Compound Comptroller Address
     */
    function getComptrollerAddress() public pure returns (address troller) {
        troller = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    }

    /**
     * @dev get CETH Address
     */
    function getCETHAddress() public pure returns (address cEth) {
        cEth = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
    }

    /**
     * @dev get DAI Address
     */
    function getDAIAddress() public pure returns (address dai) {
        dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    }

    /**
     * @dev get CDAI Address
     */
    function getCDAIAddress() public pure returns (address cDai) {
        cDai = 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643;
    }

    /**
     * @dev setting allowance to compound contracts for the "user proxy" if required
     */
    function setApproval(address erc20, uint srcAmt, address to) internal {
        TokenInterface erc20Contract = TokenInterface(erc20);
        uint tokenAllowance = erc20Contract.allowance(address(this), to);
        if (srcAmt > tokenAllowance) {
            erc20Contract.approve(to, uint(-1));
        }
    }

}


contract InstaPoolResolver is Helper {

    function accessDai(uint daiAmt, bool isCompound) internal {
        address[] memory borrowAddr = new address[](1);
        uint[] memory borrowAmt = new uint[](1);
        borrowAddr[0] = getCDAIAddress();
        borrowAmt[0] = daiAmt;
        PoolInterface(getPoolAddr()).accessToken(borrowAddr, borrowAmt, isCompound);

    }

    function returnDai(uint daiAmt, bool isCompound) internal {
        address[] memory borrowAddr = new address[](1);
        borrowAddr[0] = getCDAIAddress();
        require(TokenInterface(getDAIAddress()).transfer(getPoolAddr(), daiAmt), "Not-enough-DAI");
        PoolInterface(getPoolAddr()).paybackToken(borrowAddr, isCompound);
    }

}


contract MakerHelper is InstaPoolResolver {

    event LogOpen(uint cdpNum, address owner);
    event LogLock(uint cdpNum, uint amtETH, address owner);
    event LogFree(uint cdpNum, uint amtETH, address owner);
    event LogDraw(uint cdpNum, uint daiAmt, address owner);
    event LogWipe(uint cdpNum, uint daiAmt, address owner);

    /**
     * @dev Allowance to Maker's contract
     */
    function setMakerAllowance(TokenInterface _token, address _spender) internal {
        if (_token.allowance(address(this), _spender) != uint(-1)) {
            _token.approve(_spender, uint(-1));
        }
    }

    /**
     * @dev Check if entered amt is valid or not (Used in makerToCompound)
     */
    function checkVault(uint id, uint ethAmt, uint daiAmt) internal view returns (uint ethCol, uint daiDebt) {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        address urn = ManagerLike(manager).urns(id);
        bytes32 ilk = ManagerLike(manager).ilks(id);
        uint art = 0;
        (ethCol, art) = VatLike(ManagerLike(manager).vat()).urns(ilk, urn);
        (,uint rate,,,) = VatLike(ManagerLike(manager).vat()).ilks(ilk);
        daiDebt = rmul(art,rate);
        daiDebt = daiAmt < daiDebt ? daiAmt : daiDebt; // if DAI amount > max debt. Set max debt
        ethCol = ethAmt < ethCol ? ethAmt : ethCol; // if ETH amount > max Col. Set max col
    }

    function joinDaiJoin(address urn, uint wad) internal {
        address daiJoin = InstaMcdAddress(getMcdAddresses()).daiJoin();
        // Approves adapter to take the DAI amount
        DaiJoinLike(daiJoin).dai().approve(daiJoin, wad);
        // Joins DAI into the vat
        DaiJoinLike(daiJoin).join(urn, wad);
    }

    function _getDrawDart(
        address vat,
        address jug,
        address urn,
        bytes32 ilk,
        uint wad
    ) internal returns (int dart)
    {
        // Updates stability fee rate
        uint rate = JugLike(jug).drip(ilk);

        // Gets DAI balance of the urn in the vat
        uint dai = VatLike(vat).dai(urn);

        // If there was already enough DAI in the vat balance, just exits it without adding more debt
        if (dai < mul(wad, RAY)) {
            // Calculates the needed dart so together with the existing dai in the vat is enough to exit wad amount of DAI tokens
            dart = toInt(sub(mul(wad, RAY), dai) / rate);
            // This is neeeded due lack of precision. It might need to sum an extra dart wei (for the given DAI wad amount)
            dart = mul(uint(dart), rate) < mul(wad, RAY) ? dart + 1 : dart;
        }
    }

    function _getWipeDart(
        address vat,
        uint dai,
        address urn,
        bytes32 ilk
    ) internal view returns (int dart)
    {
        // Gets actual rate from the vat
        (, uint rate,,,) = VatLike(vat).ilks(ilk);
        // Gets actual art value of the urn
        (, uint art) = VatLike(vat).urns(ilk, urn);

        // Uses the whole dai balance in the vat to reduce the debt
        dart = toInt(dai / rate);
        // Checks the calculated dart is not higher than urn.art (total debt), otherwise uses its value
        dart = uint(dart) <= art ? - dart : - toInt(art);
    }

    function joinEthJoin(address urn, uint _wad) internal {
        address ethJoin = InstaMcdAddress(getMcdAddresses()).ethAJoin();
        // Wraps ETH in WETH
        GemJoinLike(ethJoin).gem().deposit.value(_wad)();
        // Approves adapter to take the WETH amount
        GemJoinLike(ethJoin).gem().approve(address(ethJoin), _wad);
        // Joins WETH collateral into the vat
        GemJoinLike(ethJoin).join(urn, _wad);
    }

}


contract CompoundHelper is MakerHelper {

    event LogMint(address erc20, address cErc20, uint tokenAmt, address owner);
    event LogRedeem(address erc20, address cErc20, uint tokenAmt, address owner);
    event LogBorrow(address erc20, address cErc20, uint tokenAmt, address owner);
    event LogRepay(address erc20, address cErc20, uint tokenAmt, address owner);

    /**
     * @dev Compound Enter Market which allows borrowing
     */
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

}


contract MakerResolver is CompoundHelper {
    function flux(uint cdp, address dst, uint wad) internal {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        ManagerLike(manager).flux(cdp, dst, wad);
    }

    function move(uint cdp, address dst, uint rad) public {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        ManagerLike(manager).move(cdp, dst, rad);
    }

    function frob(uint cdp, int dink, int dart) internal {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        ManagerLike(manager).frob(cdp, dink, dart);
    }

    function open() public returns (uint cdp) {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        bytes32 ilk = 0x4554482d41000000000000000000000000000000000000000000000000000000;
        cdp = ManagerLike(manager).open(ilk, address(this));
        emit LogOpen(cdp, address(this));
    }

    function give(uint cdp, address usr) public {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        ManagerLike(manager).give(cdp, usr);
    }

    function lock(uint cdp, uint _wad) internal {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        // Receives ETH amount, converts it to WETH and joins it into the vat
        joinEthJoin(address(this), _wad);
        // Locks WETH amount into the CDP
        VatLike(ManagerLike(manager).vat()).frob(
            ManagerLike(manager).ilks(cdp),
            ManagerLike(manager).urns(cdp),
            address(this),
            address(this),
            toInt(_wad),
            0
        );
        emit LogLock(cdp, _wad, address(this));
    }

    function free(uint cdp, uint wad) internal {
        address ethJoin = InstaMcdAddress(getMcdAddresses()).ethAJoin();
        // Unlocks WETH amount from the CDP
        frob(
            cdp,
            -toInt(wad),
            0
        );
        // Moves the amount from the CDP urn to proxy's address
        flux(
            cdp,
            address(this),
            wad
        );
        // Exits WETH amount to proxy address as a token
        GemJoinLike(ethJoin).exit(address(this), wad);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wad);
        emit LogFree(cdp, wad, address(this));
    }

    function draw(uint cdp, uint wad) internal {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        address jug = InstaMcdAddress(getMcdAddresses()).jug();
        address daiJoin = InstaMcdAddress(getMcdAddresses()).daiJoin();
        address urn = ManagerLike(manager).urns(cdp);
        address vat = ManagerLike(manager).vat();
        bytes32 ilk = ManagerLike(manager).ilks(cdp);
        // Generates debt in the CDP
        frob(
            cdp,
            0,
            _getDrawDart(
                vat,
                jug,
                urn,
                ilk,
                wad
            )
        );
        // Moves the DAI amount (balance in the vat in rad) to proxy's address
        move(
            cdp,
            address(this),
            toRad(wad)
        );
        // Allows adapter to access to proxy's DAI balance in the vat
        if (VatLike(vat).can(address(this), address(daiJoin)) == 0) {
            VatLike(vat).hope(daiJoin);
        }
        // Exits DAI to the user's wallet as a token
        DaiJoinLike(daiJoin).exit(address(this), wad);
        emit LogDraw(cdp, wad, address(this));

    }

    function wipe(uint cdp, uint wad) internal {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        address vat = ManagerLike(manager).vat();
        address urn = ManagerLike(manager).urns(cdp);
        bytes32 ilk = ManagerLike(manager).ilks(cdp);

        address own = ManagerLike(manager).owns(cdp);
        if (own == address(this) || ManagerLike(manager).cdpCan(own, cdp, address(this)) == 1) {
            // Joins DAI amount into the vat
            joinDaiJoin(urn, wad);
            // Paybacks debt to the CDP
            frob(
                cdp,
                0,
                _getWipeDart(
                    vat,
                    VatLike(vat).dai(urn),
                    urn,
                    ilk
                )
            );
        } else {
             // Joins DAI amount into the vat
            joinDaiJoin(address(this), wad);
            // Paybacks debt to the CDP
            VatLike(vat).frob(
                ilk,
                urn,
                address(this),
                address(this),
                0,
                _getWipeDart(
                    vat,
                    wad * RAY,
                    urn,
                    ilk
                )
            );
        }
        emit LogWipe(cdp, wad, address(this));
    }

    /**
     * @dev Run wipe & Free function together
     */
    function wipeAndFreeMaker(
        uint cdpNum,
        uint jam,
        uint _wad,
        bool isCompound
    ) internal
    {
        accessDai(_wad, isCompound);
        wipe(cdpNum, _wad);
        free(cdpNum, jam);
    }

    /**
     * @dev Run Lock & Draw function together
     */
    function lockAndDrawMaker(
        uint cdpNum,
        uint jam,
        uint _wad,
        bool isCompound
    ) internal
    {
        lock(cdpNum, jam);
        draw(cdpNum, _wad);
        returnDai(_wad, isCompound);
    }

}


contract CompoundResolver is MakerResolver {

    /**
     * @dev Deposit ETH and mint CETH
     */
    function mintCEth(uint tokenAmt) internal {
        enterMarket(getCETHAddress());
        CETHInterface cToken = CETHInterface(getCETHAddress());
        cToken.mint.value(tokenAmt)();
        emit LogMint(
            getAddressETH(),
            getCETHAddress(),
            tokenAmt,
            msg.sender
        );
    }

    /**
     * @dev borrow DAI
     */
    function borrowDAIComp(uint daiAmt, bool isCompound) internal {
        enterMarket(getCDAIAddress());
        require(CTokenInterface(getCDAIAddress()).borrow(daiAmt) == 0, "got collateral?");
        // Returning Liquidity to Liquidity Contract
        returnDai(daiAmt, isCompound);
        emit LogBorrow(
            getDAIAddress(),
            getCDAIAddress(),
            daiAmt,
            address(this)
        );
    }

    /**
     * @dev Pay DAI Debt
     */
    function repayDaiComp(uint tokenAmt, bool isCompound) internal returns (uint wipeAmt) {
        CERC20Interface cToken = CERC20Interface(getCDAIAddress());
        uint daiBorrowed = cToken.borrowBalanceCurrent(address(this));
        wipeAmt = tokenAmt < daiBorrowed ? tokenAmt : daiBorrowed;
        // Getting Liquidity from Liquidity Contract
        accessDai(wipeAmt, isCompound);
        setApproval(getDAIAddress(), wipeAmt, getCDAIAddress());
        require(cToken.repayBorrow(wipeAmt) == 0, "transfer approved?");
        emit LogRepay(
            getDAIAddress(),
            getCDAIAddress(),
            wipeAmt,
            address(this)
        );
    }

    /**
     * @dev Redeem CETH
     */
    function redeemCETH(uint tokenAmt) internal returns(uint ethAmtReddemed) {
        CTokenInterface cToken = CTokenInterface(getCETHAddress());
        uint cethBal = cToken.balanceOf(address(this));
        uint exchangeRate = cToken.exchangeRateCurrent();
        uint cethInEth = wmul(cethBal, exchangeRate);
        setApproval(getCETHAddress(), 2**128, getCETHAddress());
        ethAmtReddemed = tokenAmt;
        if (tokenAmt > cethInEth) {
            require(cToken.redeem(cethBal) == 0, "something went wrong");
            ethAmtReddemed = cethInEth;
        } else {
            require(cToken.redeemUnderlying(tokenAmt) == 0, "something went wrong");
        }
        emit LogRedeem(
            getAddressETH(),
            getCETHAddress(),
            ethAmtReddemed,
            address(this)
        );
    }

    /**
     * @dev run mint & borrow together
     */
    function mintAndBorrowComp(uint ethAmt, uint daiAmt, bool isCompound) internal {
        mintCEth(ethAmt);
        borrowDAIComp(daiAmt, isCompound);
    }

    /**
     * @dev run payback & redeem together
     */
    function paybackAndRedeemComp(uint ethCol, uint daiDebt, bool isCompound) internal returns (uint ethAmt, uint daiAmt) {
        daiAmt = repayDaiComp(daiDebt, isCompound);
        ethAmt = redeemCETH(ethCol);
    }

    /**
     * @dev Check if entered amt is valid or not (Used in makerToCompound)
     */
    function checkCompound(uint ethAmt, uint daiAmt) internal returns (uint ethCol, uint daiDebt) {
        CTokenInterface cEthContract = CTokenInterface(getCETHAddress());
        uint cEthBal = cEthContract.balanceOf(address(this));
        uint ethExchangeRate = cEthContract.exchangeRateCurrent();
        ethCol = wmul(cEthBal, ethExchangeRate);
        ethCol = wdiv(ethCol, ethExchangeRate) <= cEthBal ? ethCol : ethCol - 1;
        ethCol = ethCol <= ethAmt ? ethCol : ethAmt; // Set Max if amount is greater than the Col user have

        daiDebt = CERC20Interface(getCDAIAddress()).borrowBalanceCurrent(address(this));
        daiDebt = daiDebt <= daiAmt ? daiDebt : daiAmt; // Set Max if amount is greater than the Debt user have
    }

}


contract BridgeResolver is CompoundResolver {

    event LogVaultToCompound(uint ethAmt, uint daiAmt);
    event LogCompoundToVault(uint ethAmt, uint daiAmt);

    /**
     * @dev convert Maker CDP into Compound Collateral
     */
    function makerToCompound(
        uint cdpId,
        uint ethQty,
        uint daiQty,
        bool isCompound // access Liquidity from Compound
    ) external
    {
        // subtracting 0.00000001 ETH from initialPoolBal to solve Compound 8 decimal CETH error.
        uint initialPoolBal = sub(getPoolAddr().balance, 10000000000);

        (uint ethAmt, uint daiAmt) = checkVault(cdpId, ethQty, daiQty);
        wipeAndFreeMaker(
            cdpId,
            ethAmt,
            daiAmt,
            isCompound
        ); // Getting Liquidity inside Wipe function

        enterMarket(getCETHAddress());
        enterMarket(getCDAIAddress());
        mintAndBorrowComp(ethAmt, daiAmt, isCompound); // Returning Liquidity inside Borrow function

        uint finalPoolBal = getPoolAddr().balance;
        assert(finalPoolBal >= initialPoolBal);

        emit LogVaultToCompound(ethAmt, daiAmt);
    }

    /**
     * @dev convert Compound Collateral into Maker CDP
     * @param cdpId = 0, if user don't have any CDP
     */
    function compoundToMaker(
        uint cdpId,
        uint ethQty,
        uint daiQty,
        bool isCompound
    ) external
    {
        // subtracting 0.00000001 ETH from initialPoolBal to solve Compound 8 decimal CETH error.
        uint initialPoolBal = sub(getPoolAddr().balance, 10000000000);

        uint cdpNum = cdpId > 0 ? cdpId : open();
        (uint ethCol, uint daiDebt) = checkCompound(ethQty, daiQty);
        (uint ethAmt, uint daiAmt) = paybackAndRedeemComp(ethCol, daiDebt, isCompound); // Getting Liquidity inside Wipe function
        ethAmt = ethAmt < address(this).balance ? ethAmt : address(this).balance;
        lockAndDrawMaker(
            cdpNum,
            ethAmt,
            daiAmt,
            isCompound
        ); // Returning Liquidity inside Borrow function

        uint finalPoolBal = getPoolAddr().balance;
        assert(finalPoolBal >= initialPoolBal);

        emit LogCompoundToVault(ethAmt, daiAmt);
    }
}


contract InstaVaultCompBridge is BridgeResolver {
    function() external payable {}
}