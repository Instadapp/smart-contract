pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

interface AddressRegistry {
    function getAddr(string calldata name) external view returns (address);
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
    function tokenToEthTransferInput(uint256 tokens_sold, uint256 min_tokens, uint256 deadline, address recipient)
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
        require(msg.sender == getAddress("admin"), "Permission Denied");
        _;
    }
    function getAddress(string memory name) internal view returns (address) {
        AddressRegistry addrReg = AddressRegistry(addressRegistry);
        return addrReg.getAddr(name);
    }
}

contract UniswapTrade is Registry {
    using SafeMath for uint;

    // Get Uniswap's Exchange address from Factory Contract
    function _getExchangeAddress(address _token) internal view returns (address) {
        UniswapFactory uniswapMain = UniswapFactory(getAddress("uniswap"));
        return uniswapMain.getExchange(_token);
    }

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

    /**
     * @dev Uniswap's get expected rate from source
     * @param src - Token address to sell (for ETH it's "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
     * @param dest - Token address to buy (for ETH it's "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
     * @param srcAmt - source token amount
    */
    function getExpectedRateSrcUniswap(address src, address dest, uint srcAmt) external view returns (uint256) {
        if (src == getAddress("eth")) {
            // define uniswap exchange with dest address
            UniswapExchange exchangeContract = UniswapExchange(_getExchangeAddress(dest));
            return exchangeContract.getEthToTokenInputPrice(srcAmt);
        } else if (dest == getAddress("eth")) {
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
    function getExpectedRateDestUniswap(address src, address dest, uint destAmt) external view returns (uint256) {
        address eth = getAddress("eth");
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
        address eth = getAddress("eth");
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
        address eth = getAddress("eth");
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
