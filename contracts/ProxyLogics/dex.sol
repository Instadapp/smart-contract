pragma solidity 0.5.0;


import "./safemath.sol";

interface IERC20 {
    function balanceOf(address who) external view returns (uint256);
    function allowance(address _owner, address _spender) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface AddressRegistry {
    function getAddr(string calldata name) external view returns (address);
}

// Kyber's contract Interface
interface KyberExchange {
    // Kyber's trade function
    function trade(address src, uint srcAmount, address dest, address destAddress, uint maxDestAmount, uint minConversionRate, address walletId) external payable returns (uint);
    // Kyber's Get expected Rate function
    function getExpectedRate(address src, address dest, uint srcQty) external view returns (uint, uint);
}

// Uniswap's factory Interface
interface UniswapFactory {
    // get exchange from token's address
    function getExchange(address token) external view returns (address exchange);
}

// Uniswap's exchange Interface
interface UniswapExchange {
    // Get Prices
    function getEthToTokenInputPrice(uint256 eth_sold) external view returns (uint256 tokens_bought);
    function getEthToTokenOutputPrice(uint256 tokens_bought) external view returns (uint256 eth_sold);
    function getTokenToEthInputPrice(uint256 tokens_sold) external view returns (uint256 eth_bought);
    function getTokenToEthOutputPrice(uint256 eth_bought) external view returns (uint256 tokens_sold);
    // Trade ETH to ERC20
    function ethToTokenTransferInput(uint256 min_tokens, uint256 deadline, address recipient) external payable returns (uint256  tokens_bought);
    function ethToTokenTransferOutput(uint256 tokens_bought, uint256 deadline, address recipient) external payable returns (uint256  eth_sold);
    // Trade ERC20 to ETH
    function tokenToEthTransferInput(uint256 tokens_sold, uint256 min_tokens, uint256 deadline, address recipient) external returns (uint256  eth_bought);
    function tokenToEthTransferOutput(uint256 eth_bought, uint256 max_tokens, uint256 deadline, address recipient) external returns (uint256  tokens_sold);
    // Trade ERC20 to ERC20
    function tokenToTokenTransferInput(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_eth_bought, uint256 deadline, address recipient, address token_addr) external returns (uint256  tokens_bought);
    function tokenToTokenTransferOutput(uint256 tokens_bought, uint256 max_tokens_sold, uint256 max_eth_sold, uint256 deadline, address recipient, address token_addr) external returns (uint256  tokens_sold);
}


contract Registry {
    address public addressRegistry;
    modifier onlyAdmin() {
        require(msg.sender == _getAddress("admin"), "Permission Denied");
        _;
    }
    function _getAddress(string memory name) internal view returns (address) {
        AddressRegistry addrReg = AddressRegistry(addressRegistry);
        return addrReg.getAddr(name);
    }
}

// common stuffs in Kyber and Uniswap's trade
contract commonStuffs {

    using SafeMath for uint;

    // Check required ETH Quantity to execute code 
    function _getToken(
        address trader,
        address src,
        uint srcAmt,
        address eth
    ) internal returns (uint ethQty) {
        if (src == eth) {
            require(msg.value == srcAmt, "Invalid Operation");
            ethQty = srcAmt;
        } else {
            IERC20 tokenFunctions = IERC20(src);
            tokenFunctions.transferFrom(trader, address(this), srcAmt);
            ethQty = 0;
        }
    }

    function _approveDexes(address token, address dexToApprove) internal returns (bool) {
        IERC20 tokenFunctions = IERC20(token);
        return tokenFunctions.approve(dexToApprove, uint(0-1));
    }

    function _allowance(address token, address spender) internal view returns (uint) {
        IERC20 tokenFunctions = IERC20(token);
        return tokenFunctions.allowance(address(this), spender);
    }
    
}


// Kyber's dex functions
contract kyber is Registry, commonStuffs {

    function getExpectedRateKyber(address src, address dest, uint srcAmt) public view returns (uint, uint) {
        KyberExchange kyberFunctions = KyberExchange(_getAddress("kyber"));
        return kyberFunctions.getExpectedRate(src, dest, srcAmt);
    }

    function _approveKyber(address token) internal returns (bool) {
        address kyberProxy = _getAddress("kyber");
        return _approveDexes(token, kyberProxy);
    }

    /**
     * @title Kyber's trade when token to sell Amount fixed
     * @param src - Token address to sell (for ETH it's "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
     * @param srcAmt - amount of token for sell
     * @param dest - Token address to buy (for ETH it's "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
     * @param minDestAmt - min amount of token to buy (slippage)
    */
    function tradeSrcKyber(
        address src, // token to sell
        uint srcAmt, // amount of token for sell
        address dest, // token to buy
        uint minDestAmt // minimum slippage rate
    ) public payable returns (uint tokensBought) {
        address eth = _getAddress("eth");
        uint ethQty = _getToken(
            msg.sender,
            src,
            srcAmt,
            eth
        );

        // Interacting with Kyber Proxy Contract
        KyberExchange kyberFunctions = KyberExchange(_getAddress("kyber"));
        tokensBought = kyberFunctions.trade.value(ethQty)(
            src,
            srcAmt,
            dest,
            msg.sender,
            uint(0-1),
            minDestAmt,
            _getAddress("admin")
        );

    }

    function tradeDestKyber(
        address src, // token to sell
        uint maxSrcAmt, // amount of token for sell
        address dest, // token to buy
        uint destAmt // minimum slippage rate
    ) public payable returns (uint tokensBought) {
        address eth = _getAddress("eth");
        uint ethQty = _getToken(
            msg.sender,
            src,
            maxSrcAmt,
            eth
        );

        // Interacting with Kyber Proxy Contract
        KyberExchange kyberFunctions = KyberExchange(_getAddress("kyber"));
        tokensBought = kyberFunctions.trade.value(ethQty)(
            src,
            maxSrcAmt,
            dest,
            msg.sender,
            destAmt,
            destAmt,
            _getAddress("admin")
        );

        // maxDestAmt usecase implementated
        if (src == eth && address(this).balance > 0) {
            msg.sender.transfer(address(this).balance);
        } else if (src != eth) {
            // as there is no balanceOf of eth
            IERC20 srcTkn = IERC20(src);
            uint srcBal = srcTkn.balanceOf(address(this));
            if (srcBal > 0) {
                srcTkn.transfer(msg.sender, srcBal);
            }
        }

    }

}


// Uinswap's dex functions
contract uniswap is Registry, commonStuffs {

    // Get Uniswap's Exchange address from Factory Contract
    function _getExchangeAddress(address _token) internal view returns (address) {
        UniswapFactory uniswapMain = UniswapFactory(_getAddress("uniswap"));
        return uniswapMain.getExchange(_token);
    }

    /**
     * @title Uniswap's get expected rate from source
     * @param src - Token address to sell (for ETH it's "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
     * @param dest - Token address to buy (for ETH it's "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
     * @param srcAmt - source token amount
    */
    function getExpectedRateSrcUniswap(
        address src,
        address dest,
        uint srcAmt
    ) external view returns (uint256) {
        address eth = _getAddress("eth");
        if (src == eth) {
            // define uniswap exchange with dest address
            UniswapExchange exchangeContract = UniswapExchange(_getExchangeAddress(dest));
            return exchangeContract.getEthToTokenInputPrice(srcAmt);
        } else if (dest == eth) {
            // define uniswap exchange with src address
            UniswapExchange exchangeContract = UniswapExchange(_getExchangeAddress(src));
            return exchangeContract.getTokenToEthInputPrice(srcAmt);
        } else {
            UniswapExchange exchangeContractSrc = UniswapExchange(_getExchangeAddress(src));
            UniswapExchange exchangeContractDest = UniswapExchange(_getExchangeAddress(dest));
            uint ethQty = exchangeContractSrc.getTokenToEthInputPrice(srcAmt);
            return exchangeContractDest.getEthToTokenInputPrice(ethQty);
        }
    }

    /**
     * @title Uniswap's get expected rate from dest
     * @param src - Token address to sell (for ETH it's "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
     * @param dest - Token address to buy (for ETH it's "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
     * @param destAmt - dest token amount
    */
    function getExpectedRateDestUniswap(
        address src,
        address dest,
        uint destAmt
    ) external view returns (uint256) {
        address eth = _getAddress("eth");
        if (src == eth) {
            // define uniswap exchange with dest address
            UniswapExchange exchangeContract = UniswapExchange(_getExchangeAddress(dest));
            return exchangeContract.getEthToTokenOutputPrice(destAmt);
        } else if (dest == eth) {
            // define uniswap exchange with src address
            UniswapExchange exchangeContract = UniswapExchange(_getExchangeAddress(src));
            return exchangeContract.getTokenToEthOutputPrice(destAmt);
        } else {
            UniswapExchange exchangeContractSrc = UniswapExchange(_getExchangeAddress(src));
            UniswapExchange exchangeContractDest = UniswapExchange(_getExchangeAddress(dest));
            uint ethQty = exchangeContractDest.getTokenToEthInputPrice(destAmt);
            return exchangeContractSrc.getEthToTokenInputPrice(ethQty);
        }
    }


    /**
     * @title Uniswap's trade when token to sell Amount fixed
     * @param src - Token address to sell (for ETH it's "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
     * @param srcAmt - amount of token for sell
     * @param dest - Token address to buy (for ETH it's "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
     * @param minDestAmt - min amount of token to buy (slippage)
     * @param deadline - time for this transaction to be valid
    */
    function tradeSrcUniswap(
        address src,
        uint srcAmt,
        address dest,
        uint minDestAmt,
        uint deadline
    ) public payable returns (uint) {

        address eth = _getAddress("eth");
        uint ethQty = _getToken(
            msg.sender,
            src,
            srcAmt,
            eth
        );

        if (src == eth) {
            UniswapExchange exchangeContract = UniswapExchange(_getExchangeAddress(dest));
            uint tokensBought = exchangeContract.ethToTokenTransferInput.value(ethQty)(minDestAmt, deadline, msg.sender);
            return tokensBought;
        } else if (dest == eth) {
            UniswapExchange exchangeContract = UniswapExchange(_getExchangeAddress(src));
            uint ethBought = exchangeContract.tokenToEthTransferInput(srcAmt, minDestAmt, deadline, msg.sender);
            return ethBought;
        } else {
            UniswapExchange exchangeContract = UniswapExchange(_getExchangeAddress(src));
            uint tokensBought = exchangeContract.tokenToTokenTransferInput(srcAmt, minDestAmt, uint(0), deadline, msg.sender, dest);
            return tokensBought;
        }
    }


    /**
     * @title Uniswap's trade when token to buy Amount fixed
     * @param src - Token address to sell (for ETH it's "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
     * @param maxSrcAmt - max amount of token for sell (slippage)
     * @param dest - Token address to buy (for ETH it's "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
     * @param destAmt - amount of token to buy
     * @param deadline - time for this transaction to be valid
    */
    function tradeDestUniswap(
        address src,
        uint maxSrcAmt,
        address dest,
        uint destAmt,
        uint deadline
    ) public payable returns (uint) {

        address eth = _getAddress("eth");
        uint ethQty = _getToken(
            msg.sender,
            src,
            maxSrcAmt,
            eth
        );

        if (src == eth) {
            UniswapExchange exchangeContract = UniswapExchange(_getExchangeAddress(dest));
            uint ethSold = exchangeContract.ethToTokenTransferOutput.value(ethQty)(destAmt, deadline, msg.sender);
            if (ethSold < ethQty) {
                uint srcToReturn = ethQty - ethSold;
                msg.sender.transfer(srcToReturn);
            }
            return ethSold;
        } else if (dest == eth) {
            UniswapExchange exchangeContract = UniswapExchange(_getExchangeAddress(src));
            uint tokensSold = exchangeContract.tokenToEthTransferOutput(destAmt, maxSrcAmt, deadline, msg.sender);
            if (tokensSold < maxSrcAmt) {
                IERC20 srcTkn = IERC20(src);
                uint srcToReturn = maxSrcAmt - tokensSold;
                srcTkn.transfer(msg.sender, srcToReturn);
            }
            return tokensSold;
        } else {
            UniswapExchange exchangeContractSrc = UniswapExchange(_getExchangeAddress(src));
            uint tokensSold = exchangeContractSrc.tokenToTokenTransferOutput(destAmt, maxSrcAmt, uint(0-1), deadline, msg.sender, dest);
            if (tokensSold < maxSrcAmt) {
                IERC20 srcTkn = IERC20(src);
                uint srcToReturn = maxSrcAmt - tokensSold;
                srcTkn.transfer(msg.sender, srcToReturn);
            }
            return tokensSold;
        }

    }

}