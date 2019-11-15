pragma solidity ^0.5.8;

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

interface ManagerLike {
    function cdpCan(address, uint, address) public view returns (uint);
    function ilks(uint) public view returns (bytes32);
    function owns(uint) public view returns (address);
    function urns(uint) public view returns (address);
    function vat() public view returns (address);
    function open(bytes32, address) public returns (uint);
    function give(uint, address) public;
    function cdpAllow(uint, address, uint) public;
    function urnAllow(address, uint) public;
    function frob(uint, int, int) public;
    function flux(uint, address, uint) public;
    function move(uint, address, uint) public;
    function exit(address, uint, address, uint) public;
    function quit(uint, address) public;
    function enter(address, uint) public;
    function shift(uint, uint) public;
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

interface TokenInterface {
    function allowance(address, address) external view returns (uint);
    function balanceOf(address) external view returns (uint);
    function approve(address, uint) external;
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
    function deposit() external payable;
    function withdraw(uint) external;
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
     * @dev get MCD Manager Address
     */
    function getmanagerAddress() public pure returns (address managerAddr) { // not in use
        managerAddr;
    }

}


contract CDPResolver is Helpers {
    event LogOpen(uint cdpNum, address owner);
    event LogGive(uint cdpNum, address owner, address nextOwner);
    event LogLock(uint cdpNum, uint amtETH, address owner);
    event LogFree(uint cdpNum, uint amtETH, address owner);
    event LogDraw(uint cdpNum, uint amtDAI, address owner);
    event LogWipe(uint cdpNum, uint daiAmt, address owner);

    function open(address manager) public returns (uint cdp) {
        bytes32 ilk = 0x4554482d41000000000000000000000000000000000000000000000000000000;
        cdp = ManagerLike(manager).open(ilk);
        emit LogOpen(cdp, address(this));
    }

    function give(address manager, uint cdp,address nextOwner) public {
        ManagerLike(manager).give(cdp, nextOwner);
        emit LogGive(cdp, address(this), nextOwner);
    }

    function lockETH(address manager, address ethJoin, uint cdp) public payable {
        GemJoinLike(ethJoin).gem().deposit.value(msg.value)();
        GemJoinLike(ethJoin).gem().approve(address(ethJoin), msg.value);
        GemJoinLike(ethJoin).join(address(this), msg.value);

        // Locks WETH amount into the CDP
        VatLike(ManagerLike(manager).vat()).frob(
            ManagerLike(manager).ilks(cdp),
            ManagerLike(manager).urns(cdp),
            address(this),
            address(this),
            int(msg.value),
            0
        );
        emit LogLock(cdp, msg.value, address(this));
    }

    function freeETH(
        address manager,
        address ethJoin,
        uint cdp,
        uint wad
    ) public
    {
        ManagerLike(manager).frob(
            cdp,
            address(this),
            -int(wad),
            0
        );
        GemJoinLike(ethJoin).exit(address(this), wad);

        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wad);
        msg.sender.transfer(wad);
        emit LogFree(cdp, wad, address(this));
    }

    function draw(
        address manager,
        address jug,
        address daiJoin,
        uint cdp,
        uint wad
    ) public
    {
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
        DaiJoinLike(daiJoin).exit(msg.sender, wad);
        emit LogDraw(cdp, wad, address(this));
    }

    function wipe (
        address manager,
        address daiJoin,
        uint cdp,
        uint wad
    ) public
    {
        address vat = ManagerLike(manager).vat();
        address urn = ManagerLike(manager).urns(cdp);
        bytes32 ilk = ManagerLike(manager).ilks(cdp);

        address own = ManagerLike(manager).owns(cdp);

        (, uint rate,,,) = VatLike(vat).ilks(ilk);
        (, uint art) = VatLike(vat).urns(ilk, urn);

        DaiJoinLike(daiJoin).dai().transferFrom(msg.sender, address(this), wad);
        DaiJoinLike(daiJoin).dai().approve(daiJoin, wad);

        int dart;

        if (own == address(this) || ManagerLike(manager).cdpCan(own, cdp, address(this)) == 1) {
            DaiJoinLike(daiJoin).join(urn, wad);

            // Uses the whole dai balance in the vat to reduce the debt
            dart = toInt(VatLike(vat).dai(urn) / rate);
            // Checks the calculated dart is not higher than urn.art (total debt), otherwise uses its value
            dart = uint(dart) <= art ? - dart : - toInt(art);

            ManagerLike(manager).frob(cdp, 0, dart);
        } else {
            DaiJoinLike(daiJoin).join(address(this), wad);

            // Uses the whole dai balance in the vat to reduce the debt
            dart = toInt(wad * RAY / rate);
            // Checks the calculated dart is not higher than urn.art (total debt), otherwise uses its value
            dart = uint(dart) <= art ? - dart : - toInt(art);

            VatLike(vat).frob(
                ilk,
                urn,
                address(this),
                address(this),
                0,
                dart
            );
        }
        emit LogWipe(cdp, wad, address(this));
    }
}


contract InstaMCD is CDPResolver {

    function() external payable {}

}