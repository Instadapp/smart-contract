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
        mcd = 0xF23196DF1C440345DE07feFbe556a5eF0dcD29F0; // Check Thrilok - add addr at time of deploy
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


contract DssProxyActions is DssProxyHelpers {
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

    function hope(address obj, address usr) public {
        HopeLike(obj).hope(usr);
    }

    function nope(address obj, address usr) public {
        HopeLike(obj).nope(usr);
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

    function giveToProxy(uint cdp, address dst) public {
        address proxyRegistry = InstaMcdAddress(getMcdAddresses()).proxyRegistry(); //CHECK THRILOK -- Added proxyRegistry
        // Gets actual proxy address
        address proxy = ProxyRegistryLike(proxyRegistry).proxies(dst);
        // Checks if the proxy address already existed and dst address is still the owner
        if (proxy == address(0) || ProxyLike(proxy).owner() != dst) {
            uint csize;
            assembly {
                csize := extcodesize(dst)
            }
            // We want to avoid creating a proxy for a contract address that might not be able to handle proxies, then losing the CDP
            require(csize == 0, "Dst-is-a-contract");
            // Creates the proxy for the dst address
            proxy = ProxyRegistryLike(proxyRegistry).build(dst);
        }
        // Transfers CDP to the dst proxy
        give(cdp, proxy);
    }

    function cdpAllow(uint cdp, address usr, uint ok) public {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        ManagerLike(manager).cdpAllow(cdp, usr, ok);
    }

    function urnAllow(address usr, uint ok) public {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        ManagerLike(manager).urnAllow(usr, ok);
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

    function quit(uint cdp, address dst) public {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        ManagerLike(manager).quit(cdp, dst);
    }

    function enter(address src, uint cdp) public {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        ManagerLike(manager).enter(src, cdp);
    }

    function shift(uint cdpSrc, uint cdpOrg) public {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        ManagerLike(manager).shift(cdpSrc, cdpOrg);
    }

    function lockETH(uint cdp) public payable {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        // Receives ETH amount, converts it to WETH and joins it into the vat
        joinEthJoin(address(this));
        // Locks WETH amount into the CDP
        VatLike(ManagerLike(manager).vat()).frob(
            ManagerLike(manager).ilks(cdp),
            ManagerLike(manager).urns(cdp),
            address(this),
            address(this),
            toInt(msg.value),
            0
        );
    }

    function safeLockETH(uint cdp, address owner) public payable {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        require(ManagerLike(manager).owns(cdp) == owner, "owner-missmatch");
        lockETH(cdp);
    }

    function lockGem(
        address gemJoin,
        uint cdp,
        uint wad,
        bool transferFrom
    ) public
    {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        // Takes token amount from user's wallet and joins into the vat
        joinGemJoin(
            gemJoin,
            address(this),
            wad,
            transferFrom
        );
        // Locks token amount into the CDP
        VatLike(ManagerLike(manager).vat()).frob(
            ManagerLike(manager).ilks(cdp),
            ManagerLike(manager).urns(cdp),
            address(this),
            address(this),
            toInt(convertTo18(gemJoin, wad)),
            0
        );
    }

    function safeLockGem(
        address gemJoin,
        uint cdp,
        uint wad,
        bool transferFrom,
        address owner
    ) public
    {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        require(ManagerLike(manager).owns(cdp) == owner, "owner-missmatch");
        lockGem(
            gemJoin,
            cdp,
            wad,
            transferFrom);
    }

    function freeETH(uint cdp, uint wad) public {
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
        // Sends ETH back to the user's wallet
        msg.sender.transfer(wad);
    }

    function freeGem(address gemJoin, uint cdp, uint wad) public {
        uint wad18 = convertTo18(gemJoin, wad);
        // Unlocks token amount from the CDP
        frob(
            cdp,
            -toInt(wad18),
            0
        );
        // Moves the amount from the CDP urn to proxy's address
        flux(
            cdp,
            address(this),
            wad18
        );
        // Exits token amount to the user's wallet as a token
        GemJoinLike(gemJoin).exit(msg.sender, wad);
    }

    function exitETH(uint cdp, uint wad) public {
        address ethJoin = InstaMcdAddress(getMcdAddresses()).ethAJoin();
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
        // Sends ETH back to the user's wallet
        msg.sender.transfer(wad);
    }

    function exitGem(address gemJoin, uint cdp, uint wad) public {
        // Moves the amount from the CDP urn to proxy's address
        flux(
            cdp,
            address(this),
            convertTo18(gemJoin, wad)
        );

        // Exits token amount to the user's wallet as a token
        GemJoinLike(gemJoin).exit(msg.sender, wad);
    }

    function draw(uint cdp, uint wad) public {
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
        DaiJoinLike(daiJoin).exit(msg.sender, wad);
    }

    function wipe(uint cdp, uint wad) public {
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
    }

    function safeWipe(uint cdp, uint wad, address owner) public {
        address manager = InstaMcdAddress(getMcdAddresses()).manager();
        require(ManagerLike(manager).owns(cdp) == owner, "owner-missmatch");
        wipe(
            cdp,
            wad
        );
    }
}