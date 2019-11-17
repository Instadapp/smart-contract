pragma solidity 0.5.11;

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

interface ProxyRegistryLike {
    function proxies(address) external view returns (address);
    function build(address) external returns (address);
}

interface ProxyLike {
    function owner() external view returns (address);
}

interface InstaMcdAddress {
    function manager() external returns (address);
    function dai() external returns (address);
    function daiJoin() external returns (address);
    function jug() external returns (address);
    function proxyRegistry() external returns (address);
    function ethAJoin() external returns (address);
}


contract Common {
    uint256 constant RAY = 10 ** 27;

    /**
     * @dev get MakerDAO MCD Address contract
     */
    function getMcdAddresses() public pure returns (address mcd) {
        mcd = 0x448a5065aeBB8E423F0896E6c5D525C040f59af3; // Check Thrilok - add addr at time of deploy
    }

    /**
     * @dev get InstaDApp CDP's Address
     */
    function getGiveAddress() public pure returns (address addr) {
        addr = 0xc679857761beE860f5Ec4B3368dFE9752580B096;
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, "mul-overflow");
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, "sub-overflow");
    }

    function toInt(uint x) internal pure returns (int y) {
        y = int(x);
        require(y >= 0, "int-overflow");
    }

    function toRad(uint wad) internal pure returns (uint rad) {
        rad = mul(wad, 10 ** 27);
    }

    function convertTo18(address gemJoin, uint256 amt) internal returns (uint256 wad) {
        // For those collaterals that have less than 18 decimals precision we need to do the conversion before passing to frob function
        // Adapters will automatically handle the difference of precision
        wad = mul(
            amt,
            10 ** (18 - GemJoinLike(gemJoin).dec())
        );
    }
}


contract DssProxyHelpers is Common {
    // Internal functions
    function joinDaiJoin(address urn, uint wad) public {
        address daiJoin = InstaMcdAddress(getMcdAddresses()).daiJoin();
        // Gets DAI from the user's wallet
        DaiJoinLike(daiJoin).dai().transferFrom(msg.sender, address(this), wad);
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

    function _getWipeAllWad(
        address vat,
        address usr,
        address urn,
        bytes32 ilk
    ) internal view returns (uint wad)
    {
        // Gets actual rate from the vat
        (, uint rate,,,) = VatLike(vat).ilks(ilk);
        // Gets actual art value of the urn
        (, uint art) = VatLike(vat).urns(ilk, urn);
        // Gets actual dai amount in the urn
        uint dai = VatLike(vat).dai(usr);

        uint rad = sub(mul(art, rate), dai);
        wad = rad / RAY;

        // If the rad precision has some dust, it will need to request for 1 extra wad wei
        wad = mul(wad, RAY) < rad ? wad + 1 : wad;
    }
}


contract DssProxyActionsAdv is DssProxyHelpers {
    // Public functions

    function transfer(address gem, address dst, uint wad) public {
        GemLike(gem).transfer(dst, wad);
    }

    function joinEthJoin(address urn) public payable {
        address ethJoin = InstaMcdAddress(getMcdAddresses()).ethAJoin();
        // Wraps ETH in WETH
        GemJoinLike(ethJoin).gem().deposit.value(msg.value)();
        // Approves adapter to take the WETH amount
        GemJoinLike(ethJoin).gem().approve(address(ethJoin), msg.value);
        // Joins WETH collateral into the vat
        GemJoinLike(ethJoin).join(urn, msg.value);
    }

    function joinGemJoin(
        address apt,
        address urn,
        uint wad,
        bool transferFrom
    ) public
    {
        // Only executes for tokens that have approval/transferFrom implementation
        if (transferFrom) {
            // Gets token from the user's wallet
            GemJoinLike(apt).gem().transferFrom(msg.sender, address(this), wad);
            // Approves adapter to take the token amount
            GemJoinLike(apt).gem().approve(apt, wad);
        }
        // Joins token collateral into the vat
        GemJoinLike(apt).join(urn, wad);
    }

    function open(bytes32 ilk, address usr) public returns (uint cdp) {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        cdp = ManagerLike(manager).open(ilk, usr);
    }

    function give(uint cdp, address usr) public {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        ManagerLike(manager).give(cdp, usr);
    }

    function shut(uint cdp) public {
        give(cdp, getGiveAddress());
    }

    function flux(uint cdp, address dst, uint wad) public {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        ManagerLike(manager).flux(cdp, dst, wad);
    }

    function move(uint cdp, address dst, uint rad) public {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        ManagerLike(manager).move(cdp, dst, rad);
    }

    function frob(uint cdp, int dink, int dart) public {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        ManagerLike(manager).frob(cdp, dink, dart);
    }

    function drawAndSend(uint cdp, uint wad, address to) public {
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
        DaiJoinLike(daiJoin).exit(to, wad);
    }

    function lockETHAndDraw(uint cdp, uint wadD) public payable {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        address jug = InstaMcdAddress(getMcdAddresses()).jug();
        address daiJoin = InstaMcdAddress(getMcdAddresses()).daiJoin();
        address urn = ManagerLike(manager).urns(cdp);
        address vat = ManagerLike(manager).vat();
        bytes32 ilk = ManagerLike(manager).ilks(cdp);
        // Receives ETH amount, converts it to WETH and joins it into the vat
        joinEthJoin(urn);
        // Locks WETH amount into the CDP and generates debt
        frob(
            cdp,
            toInt(msg.value),
            _getDrawDart(
                vat,
                jug,
                urn,
                ilk,
                wadD
            )
        );
        // Moves the DAI amount (balance in the vat in rad) to proxy's address
        move(
            cdp,
            address(this),
            toRad(wadD)
        );
        // Allows adapter to access to proxy's DAI balance in the vat
        if (VatLike(vat).can(address(this), address(daiJoin)) == 0) {
            VatLike(vat).hope(daiJoin);
        }
        // Exits DAI to the user's wallet as a token
        DaiJoinLike(daiJoin).exit(msg.sender, wadD);
    }

    function openLockETHAndDraw(bytes32 ilk, uint wadD) public payable returns (uint cdp) {
        cdp = open(ilk, address(this));
        lockETHAndDraw(cdp, wadD);
    }

    function lockGemAndDraw(
        address gemJoin,
        uint cdp,
        uint wadC,
        uint wadD,
        bool transferFrom
    ) public
    {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        address jug = InstaMcdAddress(getMcdAddresses()).jug();
        address daiJoin = InstaMcdAddress(getMcdAddresses()).daiJoin();
        address urn = ManagerLike(manager).urns(cdp);
        address vat = ManagerLike(manager).vat();
        bytes32 ilk = ManagerLike(manager).ilks(cdp);
        // Takes token amount from user's wallet and joins into the vat
        joinGemJoin(
            gemJoin,
            urn,
            wadC,
            transferFrom
        );
        // Locks token amount into the CDP and generates debt
        frob(
            cdp,
            toInt(convertTo18(gemJoin, wadC)),
            _getDrawDart(
                vat,
                jug,
                urn,
                ilk,
                wadD
            )
        );
        // Moves the DAI amount (balance in the vat in rad) to proxy's address
        move(
            cdp,
            address(this),
            toRad(wadD)
        );
        // Allows adapter to access to proxy's DAI balance in the vat
        if (VatLike(vat).can(address(this), address(daiJoin)) == 0) {
            VatLike(vat).hope(daiJoin);
        }
        // Exits DAI to the user's wallet as a token
        DaiJoinLike(daiJoin).exit(msg.sender, wadD);
    }

    function openLockGemAndDraw( // check Thrilok - refactor
        address gemJoin,
        bytes32 ilk,
        uint wadC,
        uint wadD,
        bool transferFrom
    ) public returns (uint cdp)
    {
        cdp = open(ilk, address(this));
        lockGemAndDraw(
            gemJoin,
            cdp,
            wadC,
            wadD,
            transferFrom
        );
    }

    function wipeAllAndFreeEth(uint cdp) public {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        address ethJoin = InstaMcdAddress(getMcdAddresses()).ethAJoin();
        address vat = ManagerLike(manager).vat();
        address urn = ManagerLike(manager).urns(cdp);
        bytes32 ilk = ManagerLike(manager).ilks(cdp);
        (uint wadC, uint art) = VatLike(vat).urns(ilk, urn); //Check Thrilok - wadC

        // Joins DAI amount into the vat
        joinDaiJoin(
            urn,
            _getWipeAllWad(
                vat,
                urn,
                urn,
                ilk
            )
        );
        // Paybacks debt to the CDP and unlocks WETH amount from it
        frob(
            cdp,
            -toInt(wadC),
            -int(art)
        );
        // Moves the amount from the CDP urn to proxy's address
        flux(cdp, address(this), wadC);
        // Exits WETH amount to proxy address as a token
        GemJoinLike(ethJoin).exit(address(this), wadC);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wadC);
        // Sends ETH back to the user's wallet
        msg.sender.transfer(wadC);
    }

    function wipeAllAndFreeGem(uint cdp, address gemJoin) public {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        address vat = ManagerLike(manager).vat();
        address urn = ManagerLike(manager).urns(cdp);
        bytes32 ilk = ManagerLike(manager).ilks(cdp);
        (uint wadC, uint art) = VatLike(vat).urns(ilk, urn); //Check Thrilok - wadC

        // Joins DAI amount into the vat
        joinDaiJoin(
            urn,
            _getWipeAllWad(
                vat,
                urn,
                urn,
                ilk
            )
        );
        uint wad18 = convertTo18(gemJoin, wadC);
        // Paybacks debt to the CDP and unlocks token amount from it
        frob(
            cdp,
            -toInt(wad18),
            -int(art)
        );
        // Moves the amount from the CDP urn to proxy's address
        flux(cdp, address(this), wad18);
        // Exits token amount to the user's wallet as a token
        GemJoinLike(gemJoin).exit(msg.sender, wadC);
    }

    function wipeFreeGemAndShut(uint cdp, address gemJoin) public {
        wipeAllAndFreeGem(cdp, gemJoin);
        shut(cdp);
    }

    function wipeFreeEthAndShut(uint cdp) public {
        wipeAllAndFreeEth(cdp);
        shut(cdp);
    }
}