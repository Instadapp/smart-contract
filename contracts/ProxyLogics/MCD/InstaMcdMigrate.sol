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

interface InstaMcdAddress {
    function manager() external returns (address);
    function dai() external returns (address);
    function daiJoin() external returns (address);
    function vat() external returns (address);
    function jug() external returns (address);
    function cat() external returns (address);
    function gov() external returns (address);
    function adm() external returns (address);
    function vow() external returns (address);
    function spot() external returns (address);
    function pot() external returns (address);
    function esm() external returns (address);
    function mcdFlap() external returns (address);
    function mcdFlop() external returns (address);
    function mcdDeploy() external returns (address);
    function mcdEnd() external returns (address);
    function proxyActions() external returns (address);
    function proxyActionsEnd() external returns (address);
    function proxyActionsDsr() external returns (address);
    function getCdps() external returns (address);
    function saiTub() external returns (address);
    function weth() external returns (address);
    function bat() external returns (address);
    function sai() external returns (address);
    function ethAJoin() external returns (address);
    function ethAFlip() external returns (address);
    function batAJoin() external returns (address);
    function batAFlip() external returns (address);
    function ethPip() external returns (address);
    function batAPip() external returns (address);
    function saiJoin() external returns (address);
    function saiFlip() external returns (address);
    function saiPip() external returns (address);
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

}


contract Helpers is DSMath {

    /**
     * @dev get MakerDAO SCD CDP engine
     */
    function getSaiTubAddress() public pure returns (address sai) {
        sai = 0x448a5065aeBB8E423F0896E6c5D525C040f59af3;
    }

    /**
     * @dev get MakerDAO MCD Address contract
     */
    function getMcdAddresses() public pure returns (address mcd) {
        mcd = 0x448a5065aeBB8E423F0896E6c5D525C040f59af3; // Check Thrilok - add addr at time of deploy
    }

    /**
     * @dev get Sai (Dai v1) address
     */
    function getSaiAddress() public pure returns (address sai) {
        sai = 0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359;
    }

    /**
     * @dev get Sai (Dai v1) address
     */
    function getDaiAddress() public pure returns (address dai) {
        dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    }

    /**
     * @dev get Compound ETH Address
     */
    function getETHAddress() public pure returns (address ethAddr) {
        ethAddr = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; // main
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
    function getLiquidity(uint _wad) internal {
        uint[] memory _wadArr = new uint[](1);
        _wadArr[0] = _wad;

        address[] memory addrArr = new address[](1);
        addrArr[0] = address(0);

        // Get liquidity assets to payback user wallet borrowed assets
        PoolInterface(getPoolAddress()).accessToken(addrArr, _wadArr, false);
    }

    function paybackLiquidity(uint _wad) internal {
        address[] memory addrArr = new address[](1);
        addrArr[0] = address(0);

        // transfer and payback dai to InstaDApp pool.
        require(TokenInterface(getSaiAddress()).transfer(getPoolAddress(), _wad), "Not-enough-dai");
        PoolInterface(getPoolAddress()).paybackToken(addrArr, false);
    }
}


contract MKRSwapper is  LiquidityResolver {

    function swapToMkrOtc(address tokenAddr, uint govFee) internal {
        TokenInterface mkr = TubInterface(getSaiTubAddress()).gov();
        uint payAmt = OtcInterface(getOtcAddress()).getPayAmount(tokenAddr, address(mkr), govFee);
        if (tokenAddr == getETHAddress()) {
            TokenInterface weth = TokenInterface(getWETHAddress());
            weth.deposit.value(payAmt)();
        } else if (tokenAddr != getSaiAddress() && tokenAddr != getDaiAddress()) {
            require(TokenInterface(tokenAddr).transferFrom(msg.sender, address(this), payAmt), "Tranfer-failed");
        }

        setApproval(tokenAddr, payAmt, getOtcAddress());
        OtcInterface(getOtcAddress()).buyAllAmount(
            address(mkr),
            govFee,
            tokenAddr,
            payAmt
        );
    }

}


contract SCDResolver is MKRSwapper {

    function getFeeOfCdp(bytes32 cup, uint _wad) internal returns (uint feeAmt) {
        TubInterface tub = TubInterface(getSaiTubAddress());

        (bytes32 val, bool ok) = tub.pep().peek();
        TokenInterface mkr = TubInterface(getSaiTubAddress()).gov();
        feeAmt = 0;
        if (ok && val != 0) {
            // MKR required for wipe = Stability fees accrued in Dai / MKRUSD value
            uint mkrFee = rdiv(tub.rap(cup), tub.tab(cup));
            mkrFee = rmul(_wad, mkrFee);
            mkrFee = wdiv(mkrFee, uint(val));
            // convert mkr amount into sai amount
            feeAmt = OtcInterface(getOtcAddress()).getPayAmount(getSaiAddress(), address(mkr), mkrFee);
        }

    }

    function open() internal returns (bytes32 cup) {
        cup = TubInterface(getSaiTubAddress()).open();
    }

    function wipe(bytes32 cup, uint _wad, address payFeeWith) internal {
        if (_wad > 0) {
            TubInterface tub = TubInterface(getSaiTubAddress());
            TokenInterface dai = tub.sai();
            TokenInterface mkr = tub.gov();

            (address lad,,,) = tub.cups(cup);
            require(lad == address(this), "cup-not-owned");

            setAllowance(dai, getSaiTubAddress());
            setAllowance(mkr, getSaiTubAddress());

            uint mkrFee = getFeeOfCdp(cup, _wad);

            if (payFeeWith != address(mkr) && mkrFee > 0) {
                swapToMkrOtc(payFeeWith, mkrFee); //otc
            } else if (payFeeWith == address(mkr) && mkrFee > 0) {
                require(TokenInterface(address(mkr)).transferFrom(msg.sender, address(this), mkrFee), "Tranfer-failed");
            }

            tub.wipe(cup, _wad);
        }
    }

    function free(bytes32 cup, uint ink) internal {
        if (ink > 0) {
            TubInterface(getSaiTubAddress()).free(cup, ink); // free PETH
        }
    }

    function lock(bytes32 cup, uint ink) internal {
        if (ink > 0) {
            TubInterface tub = TubInterface(getSaiTubAddress());
            TokenInterface peth = tub.skr();

            (address lad,,,) = tub.cups(cup);
            require(lad == address(this), "cup-not-owned");

            setAllowance(peth, getSaiTubAddress());
            tub.lock(cup, ink);
        }
    }

    function draw(bytes32 cup, uint _wad) internal {
        if (_wad > 0) {
            TubInterface tub = TubInterface(getSaiTubAddress());
            tub.draw(cup, _wad);
        }
    }

    function setAllowance(TokenInterface _token, address _spender) private {
        if (_token.allowance(address(this), _spender) != uint(-1)) {
            _token.approve(_spender, uint(-1));
        }
    }

}


contract MCDResolver is SCDResolver {
    function migrateToMCD(
        bytes32 cup,                        // SCD CDP Id to migrate
        address payGem                    // Token address
    ) internal returns (uint cdp)
    {
        address payable scdMcdMigration = InstaMcdAddress(getMcdAddresses()).migration();
        TubInterface tub = TubInterface(getSaiTubAddress());
        tub.give(cup, address(scdMcdMigration));

        // Get necessary MKR fee and move it to the migration contract
        (bytes32 val, bool ok) = tub.pep().peek();
        if (ok && uint(val) != 0) {
            // Calculate necessary value of MKR to pay the govFee
            uint govFee = wdiv(tub.rap(cup), uint(val));
            if (govFee > 0) {
                if (payGem != address(0)) {
                    swapToMkrOtc(payGem, govFee);
                    require(tub.gov().transfer(address(scdMcdMigration), govFee), "transfer-failed");
                } else {
                    require(tub.gov().transferFrom(msg.sender, address(scdMcdMigration), govFee), "transfer-failed"); // Check Thrilok - is it working => We can directly transfer MKR to address(scdMcdMigration). Right?
                }
            }
        }
        // Execute migrate function
        cdp = MCDInterface(scdMcdMigration).migrate(cup);
    }

    function giveCDP(
        uint cdp,
        address nextOwner
    ) internal
    {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        ManagerLike(manager).give(cdp, nextOwner);
    }

    function shiftCDP(
        uint cdpSrc,
        uint cdpOrg
    ) internal
    {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        require(ManagerLike(manager).owns(cdpOrg) == address(this), "NOT-OWNER");
        ManagerLike(manager).shift(cdpSrc, cdpOrg);
    }
}


contract MigrateHelper is MCDResolver {
    function setSplitAmount(
        bytes32 cup,
        uint toConvert,
        address payFeeWith,
        address daiJoin
    ) internal returns (uint _wad, uint _ink, uint maxConvert)
    {
        // Set ratio according to user.
        TubInterface tub = TubInterface(getSaiTubAddress());

        maxConvert = toConvert;
        uint saiBal = tub.sai().balanceOf(daiJoin);
        uint _wadTotal = tub.tab(cup);

        uint feeAmt = 0;

        // wad according to toConvert ratio
        _wad = wmul(_wadTotal, toConvert);

        // if migration is by debt method, Add fee(SAI) to _wad
        if (payFeeWith == getSaiAddress()) {
            feeAmt = getFeeOfCdp(cup, _wad);
            _wad = add(_wad, feeAmt);
        }

        //if sai_join has enough sai to migrate.
        if (saiBal < _wad) {
            // set saiBal as wad amount And sub feeAmt(feeAmt > 0, when its debt method).
            _wad = sub(saiBal, add(feeAmt, 100000));
            // set new convert ratio according to sai_join balance.
            maxConvert = sub(wdiv(saiBal, _wadTotal), 100);
        }
        // ink according to maxConvert ratio.
        _ink = wmul(tub.ink(cup), maxConvert);
    }

    function splitCdp(
        bytes32 scdCup,
        bytes32 splitCup,
        uint _wad,
        uint _ink,
        address payFeeWith
    ) internal
    {
        //getting InstaDApp Pool Balance.
        uint initialPoolBal = sub(getPoolAddress().balance, 10000000000);

        // Check if the split fee is paid by debt from the cdp.
        uint _wadForDebt = payFeeWith == getSaiAddress() ? add(_wad, getFeeOfCdp(scdCup, _wad)) : _wad;

        //fetch liquidity from InstaDApp Pool.
        getLiquidity(_wadForDebt);

        //transfer assets from scdCup to splitCup.
        wipe(scdCup, _wad, payFeeWith);
        free(scdCup, _ink);
        lock(splitCup, _ink);
        draw(splitCup, _wadForDebt);

        //transfer and payback liquidity to InstaDApp Pool.
        paybackLiquidity(_wadForDebt);

        uint finalPoolBal = getPoolAddress().balance;
        assert(finalPoolBal >= initialPoolBal);
    }

    function drawDebtForFee(bytes32 cup) internal {
        // draw more SAI for debt method and 100% convert.
        uint _wad = TubInterface(getSaiTubAddress()).tab(cup);
        uint fee = getFeeOfCdp(cup, _wad);
        // draw fee amt.
        draw(cup, fee);
    }
}


contract MigrateResolver is MigrateHelper {

    event LogMigrate(uint scdCdp, uint toConvert, address payFeeWith, uint mcdCdp, uint newMcdCdp);
    event LogMigrateWithDebt(uint scdCdp, uint toConvert, address payFeeWith, uint mcdCdp, uint newMcdCdp);

    function migrate(
        uint scdCDP,
        uint mergeCDP,
        uint toConvert,
        address payFeeWith
    ) external payable returns (uint newMcdCdp)
    {
        bytes32 scdCup = bytes32(scdCDP);
        uint maxConvert = toConvert;

        if (toConvert < 10**18) {
            //new cdp for spliting assets.
            bytes32 splitCup = TubInterface(getSaiTubAddress()).open();

            //set split amount according to toConvert and dai_join balance.
            uint _wad;
            uint _ink;
            (_wad, _ink, maxConvert) = setSplitAmount(
                scdCup,
                toConvert,
                payFeeWith,
                InstaMcdAddress(getMcdAddresses()).saiJoin());

            //split the assets into split cdp.
            splitCdp(
                scdCup,
                splitCup,
                _wad,
                _ink,
                payFeeWith
            );

            //migrate the split cdp.
            newMcdCdp = migrateToMCD(splitCup, payFeeWith);
        } else {
            //migrate the scd cdp.
            newMcdCdp = migrateToMCD(scdCup, payFeeWith);
        }

        //Transfer if any ETH leftover.
        if (address(this).balance > 0) { // Check Thrilok - Can remove at time of production
            msg.sender.transfer(address(this).balance);
        }

        //merge the already existing mcd cdp with the new migrated cdp.
        if (mergeCDP != 0) {
            shiftCDP(newMcdCdp, mergeCDP);
            giveCDP(newMcdCdp, getGiveAddress());
        }

        emit LogMigrate(
            uint(scdCup),
            maxConvert,
            payFeeWith,
            mergeCDP,
            newMcdCdp
        );
    }

    function migrateWithDebt(
        uint scdCDP,
        uint mergeCDP,
        uint toConvert,
        address payFeeWith
    ) external payable returns (uint newMcdCdp)
    {
        bytes32 scdCup = bytes32(scdCDP);
        uint maxConvert = toConvert;

        if (toConvert < 10**18) {
            //new cdp for spliting assets.
            bytes32 splitCup = TubInterface(getSaiTubAddress()).open();

            //set split amount according to toConvert, feeAmt and dai_join balance.
            uint _wad;
            uint _ink;
            (_wad, _ink, maxConvert) = setSplitAmount(
                scdCup,
                toConvert,
                payFeeWith,
                InstaMcdAddress(getMcdAddresses()).saiJoin());

            //split the assets into split cdp.
            splitCdp(
                scdCup,
                splitCup,
                _wad,
                _ink,
                payFeeWith
            );

            //migrate the split cdp.
            newMcdCdp = migrateToMCD(splitCup, payFeeWith);
        } else {
            // draw extra SAI for paying fee.
            drawDebtForFee(scdCup);
            //migrate the scd cdp.
            newMcdCdp = migrateToMCD(scdCup, payFeeWith);
        }

        //Transfer if any ETH leftover.
        if (address(this).balance > 0) { // Check Thrilok - Can remove at time of production
            msg.sender.transfer(address(this).balance);
        }

        //merge the already existing mcd cdp with the new migrated cdp.
        if (mergeCDP != 0) {
            shiftCDP(newMcdCdp, mergeCDP);
            giveCDP(newMcdCdp, getGiveAddress());
        }

        emit LogMigrateWithDebt(
            uint(scdCup),
            maxConvert,
            payFeeWith,
            mergeCDP,
            newMcdCdp
        );
    }
}


contract InstaMcdMigrate is MigrateResolver {
    function() external payable {}
}