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
     * @dev get Sai (Dai v1) address
     */
    function getSaiAddress() public pure returns (address sai) {
        sai = 0x448a5065aeBB8E423F0896E6c5D525C040f59af3;
    }

    /**
     * @dev get Dai (Dai v2) address
     */
    // function getDaiAddress() public pure returns (address dai) {
    //     dai = 0x448a5065aeBB8E423F0896E6c5D525C040f59af3;
    // }

    /**
     * @dev get Compound WETH Address
     */
    function getWETHAddress() public pure returns (address wethAddr) {
        wethAddr = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // main
    }

    /**
     * @dev get uniswap MKR exchange
     */
    function getUniswapMKRExchange() public pure returns (address ume) {
        ume = 0x2C4Bd064b998838076fa341A83d007FC2FA50957;
    }

    /**
     * @dev get uniswap factory
     */
    function getUniswapFactory() public pure returns (address addr) {
        addr = 0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95;
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


contract SwapMkr is Helpers {
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
