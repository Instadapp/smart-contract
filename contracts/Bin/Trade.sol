pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

interface AddressRegistry {
    function getAddr(string calldata name) external view returns (address);
}

// Kyber's contract Interface
interface KyberExchange {
    // Kyber's trade function
    function trade(
        address src,
        uint srcAmount,
        address dest,
        address destAddress,
        uint maxDestAmount,
        uint minConversionRate,
        address walletId
    ) external payable returns (uint);
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
    function ethToTokenTransferInput(uint256 min_tokens, uint256 deadline, address recipient)
        external
        payable
        returns (uint256 tokens_bought);
    function ethToTokenTransferOutput(uint256 tokens_bought, uint256 deadline, address recipient)
        external
        payable
        returns (uint256 eth_sold);
    // Trade ERC20 to ETH
    function tokenToEthTransferInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline, address recipient)
        external
        returns (uint256 eth_bought);
    function tokenToEthTransferOutput(uint256 eth_bought, uint256 max_tokens, uint256 deadline, address recipient)
        external
        returns (uint256 tokens_sold);
    // Trade ERC20 to ERC20
    function tokenToTokenTransferInput(
        uint256 tokens_sold,
        uint256 min_tokens_bought,
        uint256 min_eth_bought,
        uint256 deadline,
        address recipient,
        address token_addr
    ) external returns (uint256 tokens_bought);
    function tokenToTokenTransferOutput(
        uint256 tokens_bought,
        uint256 max_tokens_sold,
        uint256 max_eth_sold,
        uint256 deadline,
        address recipient,
        address token_addr
    ) external returns (uint256 tokens_sold);
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
contract CommonStuffs {
    using SafeMath for uint;

    // Check required ETH Quantity to execute code
    function _getToken(address trader, address src, uint srcAmt, address eth) internal returns (uint ethQty) {
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
        return tokenFunctions.approve(dexToApprove, uint(0 - 1));
    }

    function _allowance(address token, address spender) internal view returns (uint) {
        IERC20 tokenFunctions = IERC20(token);
        return tokenFunctions.allowance(address(this), spender);
    }

}

// Kyber's dex functions
contract Kyber is Registry, CommonStuffs {
    function getExpectedRateKyber(address src, address dest, uint srcAmt) internal view returns (uint) {
        KyberExchange kyberFunctions = KyberExchange(_getAddress("kyber"));
        uint expectedRate;
        (expectedRate, ) = kyberFunctions.getExpectedRate(src, dest, srcAmt);
        uint kyberRate = expectedRate.mul(srcAmt);
        return kyberRate;
    }

    // approve to Kyber Proxy contract
    function _approveKyber(address token) internal returns (bool) {
        address kyberProxy = _getAddress("kyber");
        return _approveDexes(token, kyberProxy);
    }

    // Check Allowance to Kyber Proxy contract
    function _allowanceKyber(address token) internal view returns (uint) {
        address kyberProxy = _getAddress("kyber");
        return _allowance(token, kyberProxy);
    }

    function _allowanceApproveKyber(address token) internal returns (bool) {
        uint allowanceGiven = _allowanceKyber(token);
        if (allowanceGiven == 0) {
            return _approveKyber(token);
        } else {
            return true;
        }
    }

    /**
     * @dev Kyber's trade when token to sell Amount fixed
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
        uint ethQty = _getToken(msg.sender, src, srcAmt, eth);

        // Interacting with Kyber Proxy Contract
        KyberExchange kyberFunctions = KyberExchange(_getAddress("kyber"));
        tokensBought = kyberFunctions.trade.value(ethQty)(src, srcAmt, dest, msg.sender, uint(0 - 1), minDestAmt, _getAddress("admin"));

    }

    function tradeDestKyber(
        address src, // token to sell
        uint maxSrcAmt, // amount of token for sell
        address dest, // token to buy
        uint destAmt // minimum slippage rate
    ) public payable returns (uint tokensBought) {
        address eth = _getAddress("eth");
        uint ethQty = _getToken(msg.sender, src, maxSrcAmt, eth);

        // Interacting with Kyber Proxy Contract
        KyberExchange kyberFunctions = KyberExchange(_getAddress("kyber"));
        tokensBought = kyberFunctions.trade.value(ethQty)(src, maxSrcAmt, dest, msg.sender, destAmt, destAmt, _getAddress("admin"));

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
contract Uniswap is Registry, CommonStuffs {
    // Get Uniswap's Exchange address from Factory Contract
    function _getExchangeAddress(address _token) internal view returns (address) {
        UniswapFactory uniswapMain = UniswapFactory(_getAddress("uniswap"));
        return uniswapMain.getExchange(_token);
    }

    // Approve Uniswap's Exchanges
    function _approveUniswapExchange(address token) internal returns (bool) {
        address uniswapExchange = _getExchangeAddress(token);
        return _approveDexes(token, uniswapExchange);
    }

    // Check Allowance to Uniswap's Exchanges
    function _allowanceUniswapExchange(address token) internal view returns (uint) {
        address uniswapExchange = _getExchangeAddress(token);
        return _allowance(token, uniswapExchange);
    }

    function _allowanceApproveUniswap(address token) internal returns (bool) {
        uint allowanceGiven = _allowanceUniswapExchange(token);
        if (allowanceGiven == 0) {
            return _approveUniswapExchange(token);
        } else {
            return true;
        }
    }

    /**
     * @dev Uniswap's get expected rate from source
     * @param src - Token address to sell (for ETH it's "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
     * @param dest - Token address to buy (for ETH it's "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
     * @param srcAmt - source token amount
    */
    function getExpectedRateSrcUniswap(address src, address dest, uint srcAmt) internal view returns (uint256) {
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
     * @dev Uniswap's get expected rate from dest
     * @param src - Token address to sell (for ETH it's "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
     * @param dest - Token address to buy (for ETH it's "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
     * @param destAmt - dest token amount
    */
    function getExpectedRateDestUniswap(address src, address dest, uint destAmt) internal view returns (uint256) {
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
     * @dev Uniswap's trade when token to sell Amount fixed
     * @param src - Token address to sell (for ETH it's "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
     * @param srcAmt - amount of token for sell
     * @param dest - Token address to buy (for ETH it's "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
     * @param minDestAmt - min amount of token to buy (slippage)
     * @param deadline - time for this transaction to be valid
    */
    function tradeSrcUniswap(address src, uint srcAmt, address dest, uint minDestAmt, uint deadline) public payable returns (uint) {
        address eth = _getAddress("eth");
        uint ethQty = _getToken(msg.sender, src, srcAmt, eth);

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
     * @dev Uniswap's trade when token to buy Amount fixed
     * @param src - Token address to sell (for ETH it's "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
     * @param maxSrcAmt - max amount of token for sell (slippage)
     * @param dest - Token address to buy (for ETH it's "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
     * @param destAmt - amount of token to buy
     * @param deadline - time for this transaction to be valid
    */
    function tradeDestUniswap(address src, uint maxSrcAmt, address dest, uint destAmt, uint deadline) public payable returns (uint) {
        address eth = _getAddress("eth");
        uint ethQty = _getToken(msg.sender, src, maxSrcAmt, eth);

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
            uint tokensSold = exchangeContractSrc.tokenToTokenTransferOutput(destAmt, maxSrcAmt, uint(0 - 1), deadline, msg.sender, dest);
            if (tokensSold < maxSrcAmt) {
                IERC20 srcTkn = IERC20(src);
                uint srcToReturn = maxSrcAmt - tokensSold;
                srcTkn.transfer(msg.sender, srcToReturn);
            }
            return tokensSold;
        }

    }

}


contract Trade is Kyber, Uniswap {
    function getRateFromSrc(address src, address dest, uint srcAmt) public view returns (uint, uint) {
        uint uniswapRate = getExpectedRateSrcUniswap(src, dest, srcAmt);
        uint kyberRate = getExpectedRateKyber(src, dest, srcAmt);
        if (uniswapRate > kyberRate) {
            return (uniswapRate, 1);
        } else {
            return (kyberRate, 2);
        }
    }

    function tradeFromSrc(address src, uint srcAmt, address dest, uint minDestAmt, uint dexNum) public payable returns (uint) {
        address eth = _getAddress("eth");
        if (dexNum == 1) {
            if (src == eth) {
                return tradeSrcUniswap(src, srcAmt, dest, minDestAmt, now + 10000000);
            } else {
                _allowanceApproveUniswap(src);
                return tradeSrcUniswap(src, srcAmt, dest, minDestAmt, now + 10000000);
            }
        } else {
            if (src == eth) {
                return tradeSrcKyber(src, srcAmt, dest, minDestAmt);
            } else {
                _allowanceApproveKyber(src);
                return tradeSrcKyber(src, srcAmt, dest, minDestAmt);
            }
        }
    }

    function tradeFromDest(address src, uint maxSrcAmt, address dest, uint destAmt, uint dexNum) public payable returns (uint) {
        address eth = _getAddress("eth");
        if (dexNum == 1) {
            if (src == eth) {
                return tradeDestUniswap(src, maxSrcAmt, dest, destAmt, now + 10000000);
            } else {
                _allowanceApproveUniswap(src);
                return tradeDestUniswap(src, maxSrcAmt, dest, destAmt, now + 10000000);
            }
        } else {
            if (src == eth) {
                return tradeDestKyber(src, maxSrcAmt, dest, destAmt);
            } else {
                _allowanceApproveKyber(src);
                return tradeDestKyber(src, maxSrcAmt, dest, destAmt);
            }
        }
    }
}