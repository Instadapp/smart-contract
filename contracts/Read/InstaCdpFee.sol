pragma solidity ^0.5.0;

interface TubInterface {
    function tab(bytes32) external view returns (uint);
    function rap(bytes32) external view returns (uint);
    function pep() external view returns (PepInterface);
    function cups(bytes32) external view returns (address, uint, uint, uint);
}

interface PepInterface {
    function peek() external view returns (bytes32, bool);
}

interface InstaMcdAddress {
    function dai() external view returns (address);
    function gov() external view returns (address);
    function saiTub() external view returns (address);
    function weth() external view returns (address);
    function sai() external view returns (address);
}

interface UniswapExchange {
    function getEthToTokenOutputPrice(uint256 tokensBought) external view returns (uint256 ethSold);
    function getTokenToEthOutputPrice(uint256 ethBought) external view returns (uint256 tokensSold);
}

interface UniswapFactoryInterface {
    function getExchange(address token) external view returns (address exchange);
}

interface OtcInterface {
    function getPayAmount(address, address, uint) external view returns (uint);
}


contract DSMath {

    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, "math-not-safe");
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, "math-not-safe");
    }

    uint constant WAD = 10 ** 18;
    // uint constant RAY = 10 ** 27;

    // function rmul(uint x, uint y) internal pure returns (uint z) {
    //     z = add(mul(x, y), RAY / 2) / RAY;
    // }

    // function rdiv(uint x, uint y) internal pure returns (uint z) {
    //     z = add(mul(x, RAY), y / 2) / y;
    // }

    function wdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, WAD), y / 2) / y;
    }

}


contract CdpFee is DSMath {

    address public instaMcdAddress = 0x5092b94F61b1aa54969C67b58695a6fB15D70645;
    address public otcAddr = 0x39755357759cE0d7f32dC8dC45414CCa409AE24e;
    address public ethAddr = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public uniMkrEx = 0x2C4Bd064b998838076fa341A83d007FC2FA50957;
    address public uniFactory = 0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95;
    address public peekAddr = 0x5C1fc813d9c1B5ebb93889B3d63bA24984CA44B7;
    address public mkr = 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2;
    address public weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    
    function getMkrRate() public view returns (uint mkrInUsd) {
        (bytes32 val,) = PepInterface(peekAddr).peek();
        mkrInUsd = uint(val);
    }

    function getBestMkrSwap(address srcTknAddr, uint destMkrAmt) public view returns(uint bestEx, uint srcAmt) {
        uint oasisPrice = getOasisSwap(srcTknAddr, destMkrAmt);
        uint uniswapPrice = getUniswapSwap(srcTknAddr, destMkrAmt);
        srcAmt = oasisPrice < uniswapPrice ? oasisPrice : uniswapPrice;
        bestEx = oasisPrice < uniswapPrice ? 0 : 1; // if 0 then use Oasis for Swap, if 1 then use Uniswap
    }

    function getOasisSwap(address tokenAddr, uint destMkrAmt) public view returns(uint srcAmt) {
        address srcTknAddr = tokenAddr == ethAddr ? weth : tokenAddr;
        srcAmt = OtcInterface(otcAddr).getPayAmount(srcTknAddr, mkr, destMkrAmt);
    }

    function getUniswapSwap(address srcTknAddr, uint destMkrAmt) public view returns(uint srcAmt) {
        UniswapExchange mkrEx = UniswapExchange(uniMkrEx);
        if (srcTknAddr == ethAddr) {
            srcAmt = mkrEx.getEthToTokenOutputPrice(destMkrAmt);
        } else {
            address buyTknExAddr = UniswapFactoryInterface(uniFactory).getExchange(srcTknAddr);
            UniswapExchange buyTknEx = UniswapExchange(buyTknExAddr);
            srcAmt = buyTknEx.getTokenToEthOutputPrice(mkrEx.getEthToTokenOutputPrice(destMkrAmt)); //Check thrilok is this correct
        }
    }

}