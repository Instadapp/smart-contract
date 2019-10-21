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
     * @dev get MakerDAO CDP engine
     */
    function getSaiTubAddress() public pure returns (address sai) {
        sai = 0x448a5065aeBB8E423F0896E6c5D525C040f59af3;
    }

    function getSaiAddress() public pure returns (address sai) {
        sai = 0x448a5065aeBB8E423F0896E6c5D525C040f59af3;
    }

    function getDaiAddress() public pure returns (address dai) {
        dai = 0x448a5065aeBB8E423F0896E6c5D525C040f59af3;
    }

    /**
     * @dev get Compound WETH Address
     */
    function getWETHAddress() public pure returns (address wethAddr) {
        wethAddr = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // main
    }

    /**
     * @dev get Compound OTC Address
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
     * @dev get uniswap DAI exchange
     */
    function getUniswapDAIExchange() public pure returns (address ude) {
        ude = 0x09cabEC1eAd1c0Ba254B09efb3EE13841712bE14;
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
     * @dev setting allowance to compound for the "user proxy" if required
     */
    function setApproval(address erc20, uint srcAmt, address to) internal {
        TokenInterface erc20Contract = TokenInterface(erc20);
        uint tokenAllowance = erc20Contract.allowance(address(this), to);
        if (srcAmt > tokenAllowance) {
            erc20Contract.approve(to, 2**255);
        }
    }

}


contract SCDResolver is Helpers {

    function open() public returns (bytes32 cup) {
        cup = TubInterface(getSaiTubAddress()).open();
    }

    function wipe(bytes32 cup, uint _wad) internal {
        if (_wad > 0) {
            TubInterface tub = TubInterface(getSaiTubAddress());
            TokenInterface dai = tub.sai();
            TokenInterface mkr = tub.gov();

            (address lad,,,) = tub.cups(cup);
            require(lad == address(this), "cup-not-owned");

            setAllowance(dai, getSaiTubAddress());
            setAllowance(mkr, getSaiTubAddress());

            tub.wipe(cup, _wad);
        }
    }

    function free(bytes32 cup, uint jam) internal {
        if (jam > 0) {
            address tubAddr = getSaiTubAddress();

            TubInterface tub = TubInterface(tubAddr);
            TokenInterface peth = tub.skr();

            uint ink = rdiv(jam, tub.per());
            ink = rmul(ink, tub.per()) <= jam ? ink : ink - 1;
            tub.free(cup, ink);

            setAllowance(peth, tubAddr);

            tub.exit(ink);
            // weth.withdraw(freeJam);  // No need because we will lock it in small cdp
        }
    }

    function lock(bytes32 cup, uint jam) internal {
        if (jam > 0) {
            address tubAddr = getSaiTubAddress();

            TubInterface tub = TubInterface(tubAddr);
            TokenInterface weth = tub.gem();
            TokenInterface peth = tub.skr();

            (address lad,,,) = tub.cups(cup);
            require(lad == address(this), "cup-not-owned");

            // weth.deposit.value(msg.value)(); // no need because withdrawn Weth is not convert back

            uint ink = rdiv(jam, tub.per());
            ink = rmul(ink, tub.per()) <= jam ? ink : ink - 1;

            setAllowance(weth, tubAddr);
            tub.join(ink);

            setAllowance(peth, tubAddr);
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


contract MkrResolver is SCDResolver {
    function swapToMkrOtc(address tokenAddr, uint govFee) internal {
        TokenInterface mkr = TubInterface(getSaiTubAddress()).gov();
        uint payAmt = OtcInterface(getOtcAddress()).getPayAmount(tokenAddr, address(mkr), govFee);
        if (tokenAddr == getWETHAddress()) {
            TokenInterface weth = TokenInterface(getWETHAddress());
            weth.deposit.value(payAmt)();
        } else {
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

    function swapToMkrUniswap(address tokenAddr, uint govFee) internal {
        UniswapExchange mkrEx = UniswapExchange(getUniswapMKRExchange());
        address uniSwapFactoryAddr = 0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95;
        TokenInterface mkr = TubInterface(getSaiTubAddress()).gov();

        if (tokenAddr == getWETHAddress()) {
            uint ethNeeded = mkrEx.getEthToTokenOutputPrice(govFee);
            mkrEx.ethToTokenSwapOutput.value(ethNeeded)(govFee, uint(1899063809));
        } else {
            address buyTknExAddr = UniswapFactoryInterface(uniSwapFactoryAddr).getExchange(tokenAddr);
            UniswapExchange buyTknEx = UniswapExchange(buyTknExAddr);
            uint tknAmt = buyTknEx.getTokenToEthOutputPrice(mkrEx.getEthToTokenOutputPrice(govFee)); //Check thrilok is this correct
            require(TokenInterface(tokenAddr).transferFrom(msg.sender, address(this), tknAmt), "not-approved-yet");
            setApproval(tokenAddr, tknAmt, buyTknExAddr);
            buyTknEx.tokenToTokenSwapOutput(
                    govFee,
                    tknAmt,
                    uint(999000000000000000000),
                    uint(1899063809), // 6th March 2030 GMT // no logic
                    address(mkr)
                );
        }

    }
}


contract MCDResolver is MkrResolver {
    function swapDaiToSai(
        address payable scdMcdMigration,    // Migration contract address
        uint wad                            // Amount to swap
    ) internal
    {
        // TokenInterface sai = TokenInterface(getSaiAddress());
        TokenInterface dai = TokenInterface(getDaiAddress());
        dai.transferFrom(msg.sender, address(this), wad);
        if (dai.allowance(address(this), scdMcdMigration) < wad) {
            dai.approve(scdMcdMigration, wad);
        }
        MCDInterface(scdMcdMigration).swapDaiToSai(wad);
    }

    function migrateToMCD(
        address payable scdMcdMigration,    // Migration contract address
        bytes32 cup,                        // SCD CDP Id to migrate
        address payGem                     // Token address (only if gov fee will be paid with another token)
    ) internal returns (uint cdp)
    {
        TubInterface tub = TubInterface(getSaiTubAddress());
        tub.give(cup, address(scdMcdMigration));

        // Get necessary MKR fee and move it to the migration contract
        (bytes32 val, bool ok) = tub.pep().peek();
        if (ok && uint(val) != 0) {
            // Calculate necessary value of MKR to pay the govFee
            uint govFee = wdiv(tub.rap(cup), uint(val));

            if (payGem != address(0)) {
                swapToMkrOtc(payGem, govFee);
            } else {
                require(tub.gov().transferFrom(msg.sender, address(this), govFee), "transfer-failed");
            }
            require(tub.gov().transfer(address(scdMcdMigration), govFee), "transfer-failed");
        }
        // Execute migrate function
        cdp = MCDInterface(scdMcdMigration).migrate(cup);
    }
}


contract MigrateResolver is MCDResolver {
    event LogMigrate(uint scdCdp, uint toConvert, address payFeeWith, uint mcdCdp);
    function migrate(
        bytes32 scdCup,
        // uint mcdCDP, for merge
        uint toConvert,
        address payFeeWith,
        address payable scdMcdMigration
    ) external payable returns (uint cdp)
    {
        TubInterface tub = TubInterface(getSaiTubAddress());
        uint _jam = rmul(tub.ink(scdCup), tub.per());
        uint _wad = tub.tab(scdCup);
        if (toConvert < 10**18) {
            uint initialPoolBal = sub(getPoolAddress().balance, 10000000000);
            bytes32 splitCup = TubInterface(getSaiTubAddress()).open();

            _jam = wmul(_jam, toConvert);
            _wad = wmul(_wad, toConvert);


            uint[] memory _wadArr = new uint[](1);
            _wadArr[0] = _wad;

            address[] memory addrArr = new address[](1);
            addrArr[0] = address(0);

            // Get liquidity assets to payback user wallet borrowed assets
            PoolInterface(getPoolAddress()).accessToken(addrArr, _wadArr, false);

            (bytes32 val, bool ok) = tub.pep().peek();

            if (ok && val != 0) {
                // MKR required for wipe = Stability fees accrued in Dai / MKRUSD value
                uint mkrFee = wdiv(rmul(_wad, rdiv(tub.rap(scdCup), tub.tab(scdCup))), uint(val));
                swapToMkrUniswap(payFeeWith, mkrFee);
            }

            wipe(scdCup, _wad);
            free(scdCup, _jam);

            lock(splitCup, _jam);
            draw(splitCup, _wad);

            require(TokenInterface(getSaiAddress()).transfer(getPoolAddress(), _wad), "Not-enough-dai");
            PoolInterface(getPoolAddress()).paybackToken(addrArr, false);

            uint finalPoolBal = getPoolAddress().balance;
            assert(finalPoolBal >= initialPoolBal);

            cdp = migrateToMCD(scdMcdMigration, splitCup, payFeeWith);
        } else {
            cdp = migrateToMCD(scdMcdMigration, scdCup, payFeeWith);
        }
        emit LogMigrate(
            uint(scdCup),
            toConvert,
            payFeeWith,
            cdp
        );
    }
}


contract InstaMcdMigrate is MigrateResolver {
    function() external payable {}
}