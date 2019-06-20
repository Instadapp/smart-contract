pragma solidity ^0.5.7;

interface ERC20Interface {
    function allowance(address, address) external view returns (uint);
    function approve(address, uint) external;
}

interface TubInterface {
    function give(bytes32, address) external;
}

interface PepInterface {
    function peek() external returns (bytes32, bool);
}

interface ComptrollerInterface {
    function enterMarkets(address[] calldata cTokens) external returns (uint[] memory);
    function getAssetsIn(address account) external view returns (address[] memory);
}

interface CTokenInterface {
    function borrow(uint borrowAmount) external returns (uint);
}

interface BridgeInterface {
    function makerToCompound(uint, uint, uint) external returns (uint);
    function compoundToMaker(uint, uint, uint) external;
    function refillFunds(uint) external;
}


contract Helper {

    /**
     * @dev get MakerDAO CDP engine
     */
    function getSaiTubAddress() public pure returns (address sai) {
        sai = 0x448a5065aeBB8E423F0896E6c5D525C040f59af3;
    }

    /**
     * @dev get Compound Comptroller Address
     */
    function getComptrollerAddress() public pure returns (address troller) {
        troller = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    }

    /**
     * @dev get DAI Token Addrewss
     */
    function getDAIAddress() public pure returns (address dai) {
        dai = 0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359;
    }

    /**
     * @dev get Compound CETH Address
     */
    function getCETHAddress() public pure returns (address cEth) {
        cEth = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
    }

    /**
     * @dev get Compound CDAI Address
     */
    function getCDAIAddress() public pure returns (address cDai) {
        cDai = 0xF5DCe57282A584D2746FaF1593d3121Fcac444dC;
    }

    /**
     * @dev get MakerDAO<>Compound Bridge Contract
     */
    function getBridgeAddress() public pure returns (address bridge) {
        bridge = 0x7077C42D295A5D6C6f120FfA3C371ffaF0A0B79A;
    }

    /**
     * @dev setting allowance if required
     */
    function setApproval(address erc20, uint srcAmt, address to) internal {
        ERC20Interface erc20Contract = ERC20Interface(erc20);
        uint tokenAllowance = erc20Contract.allowance(address(this), to);
        if (srcAmt > tokenAllowance) {
            erc20Contract.approve(to, 2**255);
        }
    }

    /**
     * @dev transfer CDP ownership
     */
    function give(uint cdpNum, address nextOwner) internal {
        TubInterface(getSaiTubAddress()).give(bytes32(cdpNum), nextOwner);
    }

    /**
     * @dev enter compound market
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

    /**
     * @dev borrow DAI from compound
     */
    function borrowDAI(uint tokenAmt) internal {
        enterMarket(getCETHAddress());
        enterMarket(getCDAIAddress());
        require(CTokenInterface(getCDAIAddress()).borrow(tokenAmt) == 0, "got collateral?");
    }

}


contract Bridge is Helper {

    /**
     * @dev MakerDAO to Compound
     */
    function makerToCompound(uint cdpId, uint ethCol, uint daiDebt) public {
        give(cdpId, getBridgeAddress());
        BridgeInterface bridge = BridgeInterface(getBridgeAddress());
        uint daiAmt = bridge.makerToCompound(cdpId, ethCol, daiDebt);
        if (daiAmt > 0) {
            borrowDAI(daiAmt);
            setApproval(getDAIAddress(), daiAmt, getBridgeAddress());
            bridge.refillFunds(daiAmt);
        }
    }

    /**
     * @dev Compound to MakerDAO
     */
    function compoundToMaker(uint cdpId, uint ethCol, uint daiDebt) public {
        if (cdpId != 0) {
            give(cdpId, getBridgeAddress());
        }
        if (ethCol > 0) {
            setApproval(getCETHAddress(), 2**150, getBridgeAddress());
        }
        BridgeInterface(getBridgeAddress()).compoundToMaker(cdpId, ethCol, daiDebt);
    }

}


contract InstaBridge is Bridge {

    uint public version;

    /**
     * @dev setting up variables on deployment
     * 1...2...3 versioning in each subsequent deployments
     */
    constructor(uint _version) public {
        version = _version;
    }

    function() external payable {}

}