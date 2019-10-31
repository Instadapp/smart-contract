pragma solidity ^0.5.8;
pragma experimental ABIEncoderV2;

interface ManagerLike {
    function cdpCan(address, uint, address) external view returns (uint);
    function ilks(uint) external view returns (bytes32);
    function owns(uint) external view returns (address);
    function urns(uint) external view returns (address);
    function vat() external view returns (address);
}

interface CdpsLike {
    function getCdpsAsc(address, address) external view returns (uint[] memory, address[] memory, bytes32[] memory);
}

interface VatLike {
    function can(address, address) external view returns (uint);
    function ilks(bytes32) external view returns (uint, uint, uint, uint, uint);
    function dai(address) external view returns (uint);
    function urns(bytes32, address) external view returns (uint, uint);

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

    struct CdpData {
        uint id;
        address owner;
        bytes32 ilk;
        uint ink;
        uint art;
        uint debt;
        address urn;
    }

}


contract McdResolver is Helpers {
    function getCdpsByAddress(address manager, address cdpManger, address owner) external view returns (CdpData[] memory) {
        (uint[] memory ids, address[] memory urns, bytes32[] memory ilks) = CdpsLike(cdpManger).getCdpsAsc(manager, owner);
        CdpData[] memory cdps = new CdpData[](ids.length);

        for (uint i = 0; i < ids.length; i++) {
            (uint ink, uint art) = VatLike(ManagerLike(manager).vat()).urns(ilks[i], urns[i]);
            (,uint rate,,,) = VatLike(ManagerLike(manager).vat()).ilks(ilks[i]);
            uint debt = rmul(art,rate);
            cdps[i] = CdpData(
                ids[i],
                owner,
                ilks[i],
                ink,
                art,
                debt,
                urns[i]
            );
        }
        return cdps;
    }

    function getCdpsById(address manager, uint id) external view returns (CdpData memory) {
        address urn = ManagerLike(manager).urns(id);
        bytes32 ilk = ManagerLike(manager).ilks(id);
        address owner = ManagerLike(manager).owns(id);

        (uint ink, uint art) = VatLike(ManagerLike(manager).vat()).urns(ilk, urn);
        (,uint rate,,,) = VatLike(ManagerLike(manager).vat()).ilks(ilk);
        uint debt = rmul(art,rate);

        CdpData memory cdp = CdpData(
            id,
            owner,
            ilk,
            ink,
            art,
            debt,
            urn
        );
        return cdp;
    }

    function getIlkData(address manager, bytes32 ilk) external view returns (uint rate) {
        (,rate,,,) = VatLike(ManagerLike(manager).vat()).ilks(ilk);
    }

}
