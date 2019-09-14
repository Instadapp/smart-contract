pragma solidity ^0.5.0;

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
    function gem() external view returns (IERC20);
    function gov() external view returns (IERC20);
    function skr() external view returns (IERC20);
    function sai() external view returns (IERC20);
    function ink(bytes32) external view returns (uint);
    function tab(bytes32) external returns (uint);
    function rap(bytes32) external returns (uint);
    function per() external view returns (uint);
}

interface oracleInterface {
    function read() external view returns (bytes32);
} 

interface IERC20 {
    function allowance(address, address) external view returns (uint);
    function balanceOf(address) external view returns (uint);
    function approve(address, uint) external;
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
    function deposit() external payable;
    function withdraw(uint) external;
}

interface KyberInterface {
    function trade(
        address src,
        uint srcAmount,
        address dest,
        address destAddress,
        uint maxDestAmount,
        uint minConversionRate,
        address walletId
        ) external payable returns (uint);

    function getExpectedRate(
        address src,
        address dest,
        uint srcQty
        ) external view returns (uint, uint);
}


contract DSMath {

    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, "math-not-safe");
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, "ds-math-sub-underflow");
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

}


contract Helpers is DSMath {

    /**
     * @dev get MakerDAO CDP engine
     */
    function getSaiTubAddress() public pure returns (address sai) {
        sai = 0x448a5065aeBB8E423F0896E6c5D525C040f59af3;
    }

    /**
     * @dev get MakerDAO Oracle for ETH price
     */
    function getOracleAddress() public pure returns (address oracle) {
        oracle = 0x729D19f657BD0614b4985Cf1D82531c67569197B;
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
     * @dev get ethereum address for trade
     */
    function getAddressETH() public pure returns (address eth) {
        eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }

    /**
     * @dev get ethereum address for trade
     */
    function getAddressDAI() public pure returns (address dai) {
        dai = 0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359;
    }

    /**
     * @dev get kyber proxy address
     */
    function getAddressKyber() public pure returns (address kyber) {
        kyber = 0x818E6FECD516Ecc3849DAf6845e3EC868087B755;
    }

    /**
     * @dev get admin address
     */
    function getAddressAdmin() public pure returns (address admin) {
        admin = 0x7284a8451d9a0e7Dc62B3a71C0593eA2eC5c5638;
    }

    /**
     * @dev get CDP bytes by CDP ID
     */
    function getCDPBytes(uint cdpNum) public pure returns (bytes32 cup) {
        cup = bytes32(cdpNum);
    }

    /**
     * @dev getting rates from Kyber
     * @param src is the token being sold
     * @param dest is the token being bought
     * @param srcAmt is the amount of token being sold
     * @return expectedRate - the current rate
     * @return slippageRate - rate with 3% slippage
     */
    function getExpectedRate(
        address src,
        address dest,
        uint srcAmt
    ) public view returns (
        uint expectedRate,
        uint slippageRate
    ) 
    {
        (expectedRate,) = KyberInterface(getAddressKyber()).getExpectedRate(src, dest, srcAmt);
        slippageRate = (expectedRate / 100) * 99; // changing slippage rate upto 99%
    }

    /**
     * @dev fetching token from the trader if ERC20
     * @param trader is the trader
     * @param src is the token which is being sold
     * @param srcAmt is the amount of token being sold
     */
    function getToken(address trader, address src, uint srcAmt) internal returns (uint ethQty) {
        if (src == getAddressETH()) {
            require(msg.value == srcAmt, "not-enough-src");
            ethQty = srcAmt;
        } else {
            IERC20 tknContract = IERC20(src);
            setApproval(tknContract, srcAmt);
            tknContract.transferFrom(trader, address(this), srcAmt);
        }
    }

    /**
     * @dev setting allowance to kyber for the "user proxy" if required
     * @param tknContract is the token
     * @param srcAmt is the amount of token to sell
     */
    function setApproval(IERC20 tknContract, uint srcAmt) internal returns (uint) {
        uint tokenAllowance = tknContract.allowance(address(this), getAddressKyber());
        if (srcAmt > tokenAllowance) {
            tknContract.approve(getAddressKyber(), 2**255);
        }
    }

}


contract GetDetails is Helpers {

    function checkFinalPosition(uint cdpID) public view returns (uint finalEthCol, uint finalDaiDebt, uint finalColToUSD, uint timesPossible) {
        bytes32 cdpToBytes = bytes32(cdpID);
        TubInterface tub = TubInterface(getSaiTubAddress());
        uint usdPerEth = uint(oracleInterface(getOracleAddress()).read());
        (, uint pethCol, uint daiDebt,) = tub.cups(cdpToBytes);
        uint ethCol = rmul(pethCol, tub.per()); // get ETH col from PETH col
        (finalEthCol, finalDaiDebt, finalColToUSD, timesPossible) = _checkPositionLoop(
            ethCol,
            daiDebt,
            usdPerEth,
            0
        );
    }

    function _checkPositionLoop(
        uint ethCol,
        uint daiDebt,
        uint usdPerEth,
        uint runTime
    ) internal view returns (
        uint finalEthCol, 
        uint finalDaiDebt,
        uint finalColToUSD,
        uint timesPossible
    )
    {
        uint colToUSD = wmul(ethCol, usdPerEth) - 10;
        uint minColNeeded = wmul(daiDebt, 1500000000000000000) + 10;
        uint colToFree = wdiv(sub(colToUSD, minColNeeded), usdPerEth);
        (uint expectedRate,) = KyberInterface(getAddressKyber()).getExpectedRate(getAddressETH(), getAddressDAI(), colToFree);
        uint expectedDAI = wmul(colToFree, expectedRate);
        if (expectedDAI < daiDebt) {
            uint runTimePlus = add(runTime, 1);
            (finalEthCol, finalDaiDebt, finalColToUSD, timesPossible) = _checkPositionLoop(
                sub(ethCol, colToFree),
                sub(daiDebt, expectedDAI),
                usdPerEth,
                runTimePlus
            );
        } else {
            finalEthCol = ethCol;
            finalDaiDebt = daiDebt;
            finalColToUSD = wmul(ethCol, usdPerEth);
            timesPossible = runTime;
        }
    }

    function getFinalPosition(uint cdpID, uint runTime) public view returns (uint finalEthCol, uint finalDaiDebt, uint finalColToUSD) {
        bytes32 cdpToBytes = bytes32(cdpID);
        TubInterface tub = TubInterface(getSaiTubAddress());
        uint usdPerEth = uint(oracleInterface(getOracleAddress()).read());
        (, uint pethCol, uint daiDebt,) = tub.cups(cdpToBytes);
        uint ethCol = rmul(pethCol, tub.per()); // get ETH col from PETH col
        (finalEthCol, finalDaiDebt, finalColToUSD) = _finalPositionLoop(
            ethCol,
            daiDebt,
            usdPerEth,
            runTime
        );
    }

    function _finalPositionLoop(
        uint ethCol,
        uint daiDebt,
        uint usdPerEth,
        uint runTime
    ) internal view returns (
        uint finalEthCol, 
        uint finalDaiDebt,
        uint finalColToUSD
    )
    {
        if (runTime != 0) {
            uint colToUSD = wmul(ethCol, usdPerEth) - 10;
            require(wdiv(colToUSD, daiDebt) > 1500000000000000000, "No-margin-to-leverage");
            uint minColNeeded = wmul(daiDebt, 1500000000000000000) + 10;
            uint colToFree = wdiv(sub(colToUSD, minColNeeded), usdPerEth);
            (uint expectedRate,) = KyberInterface(getAddressKyber()).getExpectedRate(getAddressETH(), getAddressDAI(), colToFree);
            uint expectedDAI = wmul(colToFree, expectedRate);
            uint runTimeMinus = sub(runTime, 1);
            (finalEthCol, finalDaiDebt, finalColToUSD) = _finalPositionLoop(
                sub(ethCol, colToFree),
                sub(daiDebt, expectedDAI),
                usdPerEth,
                runTimeMinus
            );
        } else {
            finalEthCol = ethCol;
            finalDaiDebt = daiDebt;
            finalColToUSD = wmul(ethCol, usdPerEth);
        }
    }

}


contract Save is GetDetails {

    

}