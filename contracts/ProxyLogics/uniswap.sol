pragma solidity 0.5.0;


import "./safemath.sol";

interface IERC20 {
    function balanceOf(address who) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface AddressRegistry {
    function getAddr(string calldata name) external view returns (address);
}

interface UniswapFactoryInterface {
    // Get Exchange and Token Info
    function getExchange(address token) external view returns (address exchange);
    function getToken(address exchange) external view returns (address token);
}

// Solidity Interface
interface UniswapExchange {
    // Address of ERC20 token sold on this exchange
    function tokenAddress() external view returns (address token);
    // Address of Uniswap Factory
    function factoryAddress() external view returns (address factory);
    // Get Prices
    function getEthToTokenInputPrice(uint256 eth_sold) external view returns (uint256 tokens_bought);
    function getEthToTokenOutputPrice(uint256 tokens_bought) external view returns (uint256 eth_sold);
    function getTokenToEthInputPrice(uint256 tokens_sold) external view returns (uint256 eth_bought);
    function getTokenToEthOutputPrice(uint256 eth_bought) external view returns (uint256 tokens_sold);
    // Trade ETH to ERC20
    function ethToTokenSwapInput(uint256 min_tokens, uint256 deadline) external payable returns (uint256  tokens_bought);
    function ethToTokenTransferInput(uint256 min_tokens, uint256 deadline, address recipient) external payable returns (uint256  tokens_bought);
    function ethToTokenSwapOutput(uint256 tokens_bought, uint256 deadline) external payable returns (uint256  eth_sold);
    function ethToTokenTransferOutput(uint256 tokens_bought, uint256 deadline, address recipient) external payable returns (uint256  eth_sold);
    // Trade ERC20 to ETH
    function tokenToEthSwapInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline) external returns (uint256  eth_bought);
    function tokenToEthTransferInput(uint256 tokens_sold, uint256 min_tokens, uint256 deadline, address recipient) external returns (uint256  eth_bought);
    function tokenToEthSwapOutput(uint256 eth_bought, uint256 max_tokens, uint256 deadline) external returns (uint256  tokens_sold);
    function tokenToEthTransferOutput(uint256 eth_bought, uint256 max_tokens, uint256 deadline, address recipient) external returns (uint256  tokens_sold);
    // Trade ERC20 to ERC20
    function tokenToTokenSwapInput(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_eth_bought, uint256 deadline, address token_addr) external returns (uint256  tokens_bought);
    function tokenToTokenTransferInput(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_eth_bought, uint256 deadline, address recipient, address token_addr) external returns (uint256  tokens_bought);
    function tokenToTokenSwapOutput(uint256 tokens_bought, uint256 max_tokens_sold, uint256 max_eth_sold, uint256 deadline, address token_addr) external returns (uint256  tokens_sold);
    function tokenToTokenTransferOutput(uint256 tokens_bought, uint256 max_tokens_sold, uint256 max_eth_sold, uint256 deadline, address recipient, address token_addr) external returns (uint256  tokens_sold);
    // Trade ERC20 to Custom Pool
    function tokenToExchangeSwapInput(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_eth_bought, uint256 deadline, address exchange_addr) external returns (uint256  tokens_bought);
    function tokenToExchangeTransferInput(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_eth_bought, uint256 deadline, address recipient, address exchange_addr) external returns (uint256  tokens_bought);
    function tokenToExchangeSwapOutput(uint256 tokens_bought, uint256 max_tokens_sold, uint256 max_eth_sold, uint256 deadline, address exchange_addr) external returns (uint256  tokens_sold);
    function tokenToExchangeTransferOutput(uint256 tokens_bought, uint256 max_tokens_sold, uint256 max_eth_sold, uint256 deadline, address recipient, address exchange_addr) external returns (uint256  tokens_sold);
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

contract Trade is Registry {
    
    using SafeMath for uint;

    // Get Uniswap's Exchange address from Factory Contract
    function _getExchangeAddress(address _token) internal view returns (address) {
        UniswapFactoryInterface uniswapMain = UniswapFactoryInterface(getAddress("uniswap"));
        return uniswapMain.getExchange(_token);
    }

    /*
     * Uniswap's get expected rate function
     * @params:-
     * src - Token address to sell (for ETH it's "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
     * dest - Token address to buy (for ETH it's "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
     * srcAmtFixed - if Token to sell has fixed quantity then true else Token to sell should have fixed quantity to buy
     * srcDestAmt - if srcAmtFixed is true then quantity will be of src token else quantity will be of dest token
    */
    // function getExpectedRateUniswap(address src, address dest, bool srcAmtFixed, uint srcDestAmt) external view returns (uint256) {
    //     if (src == getAddress("eth")) {
    //         // define uniswap exchange with dest address
    //         UniswapExchange exchangeContract = UniswapExchange(_getExchangeAddress(dest));
    //         if (srcAmtFixed) {
    //             return exchangeContract.getEthToTokenInputPrice(srcDestAmt);
    //         } else {
    //             return exchangeContract.getEthToTokenOutputPrice(srcDestAmt);
    //         }
    //     } else if (dest == getAddress("eth")) {
    //         // define uniswap exchange with src address
    //         UniswapExchange exchangeContract = UniswapExchange(_getExchangeAddress(src));
    //         if (srcAmtFixed) {
    //             return exchangeContract.getTokenToEthInputPrice(srcDestAmt);
    //         } else {
    //             return exchangeContract.getTokenToEthOutputPrice(srcDestAmt);
    //         }
    //     } else {
    //         UniswapExchange exchangeContractSrc = UniswapExchange(_getExchangeAddress(src));
    //         UniswapExchange exchangeContractDest = UniswapExchange(_getExchangeAddress(dest));
    //         if (srcAmtFixed) {
    //             uint ethQty = exchangeContractSrc.getTokenToEthInputPrice(srcDestAmt);
    //             return exchangeContractDest.getEthToTokenInputPrice(ethQty);
    //         } else {
    //             uint ethQty = exchangeContractDest.getTokenToEthInputPrice(srcDestAmt);
    //             return exchangeContractSrc.getEthToTokenInputPrice(ethQty);
    //         }
    //     }
    // }

    function getExpectedRateSrcUniswap(address src, address dest, uint srcDestAmt) external view returns (uint256) {
        if (src == getAddress("eth")) {
            // define uniswap exchange with dest address
            UniswapExchange exchangeContract = UniswapExchange(_getExchangeAddress(dest));
            return exchangeContract.getEthToTokenInputPrice(srcDestAmt);
        } else if (dest == getAddress("eth")) {
            // define uniswap exchange with src address
            UniswapExchange exchangeContract = UniswapExchange(_getExchangeAddress(src));
            return exchangeContract.getTokenToEthInputPrice(srcDestAmt);
        } else {
            UniswapExchange exchangeContractSrc = UniswapExchange(_getExchangeAddress(src));
            UniswapExchange exchangeContractDest = UniswapExchange(_getExchangeAddress(dest));
            uint ethQty = exchangeContractSrc.getTokenToEthInputPrice(srcDestAmt);
            return exchangeContractDest.getEthToTokenInputPrice(ethQty);
        }
    }

    function getExpectedRateDestUniswap(address src, address dest, uint srcDestAmt) external view returns (uint256) {
        address eth = getAddress("eth");
        if (src == eth) {
            // define uniswap exchange with dest address
            UniswapExchange exchangeContract = UniswapExchange(_getExchangeAddress(dest));
            return exchangeContract.getEthToTokenOutputPrice(srcDestAmt);
        } else if (dest == eth) {
            // define uniswap exchange with src address
            UniswapExchange exchangeContract = UniswapExchange(_getExchangeAddress(src));
            return exchangeContract.getTokenToEthOutputPrice(srcDestAmt);
        } else {
            UniswapExchange exchangeContractSrc = UniswapExchange(_getExchangeAddress(src));
            UniswapExchange exchangeContractDest = UniswapExchange(_getExchangeAddress(dest));
            uint ethQty = exchangeContractDest.getTokenToEthInputPrice(srcDestAmt);
            return exchangeContractSrc.getEthToTokenInputPrice(ethQty);
        }
    }

    // function tradeUniswap(
    //     address src, // token to sell
    //     address dest, // token to buy
    //     uint srcAmt, // amount of token for sell
    //     uint destAmt, // amount of token to buy
    //     bool srcAmtFixed, // if true src has fixed qty else dest has fixed qty
    //     uint srcDestAmt,
    //     uint minSlippage // % slippage of other token than the fixed one
    // ) public payable returns (uint) {
    //     if (src == getAddress("eth")) {
    //         UniswapExchange exchangeContract = UniswapExchange(_getExchangeAddress(dest));
    //     // function ethToTokenSwapInput(uint256 min_tokens, uint256 deadline) external payable returns (uint256  tokens_bought);
    //         if (srcAmtFixed) {

    //         } else {

    //         }
    //         return exchangeContract.ethToTokenSwapInput()
    //     } else if (dest == getAddress("eth")) {
    //         UniswapExchange exchangeContract = UniswapExchange(_getExchangeAddress(src));
    //     } else {

    //     }
    // }

    function tradeSrcUniswap(
        address src, // token to sell
        address dest, // token to buy
        uint srcAmt, // amount of token for sell
        uint minDestAmt, // min dest token amount (slippage)
        uint deadline // time for this transaction to be valid
    ) public payable returns (uint) {

        address eth = getAddress("eth");
        address user = msg.sender;
        uint ethQty = getToken(
            user,
            src,
            srcAmt,
            eth
        );

        if (src == eth) {
            UniswapExchange exchangeContract = UniswapExchange(_getExchangeAddress(dest));
            uint tokensBought = exchangeContract.ethToTokenSwapInput.value(ethQty)(minDestAmt, deadline);
            return tokensBought;
        } else if (dest == eth) {
            UniswapExchange exchangeContract = UniswapExchange(_getExchangeAddress(src));
            uint ethBought = exchangeContract.tokenToEthSwapInput(srcAmt, minDestAmt, deadline);
            return ethBought;
        } else {
            
        }
    }


    function getToken(
        address trader,
        address src,
        uint srcAmt,
        address eth
    )
    internal
    returns (uint ethQty)
    {
        if (src == eth) {
            require(msg.value == srcAmt, "Invalid Operation");
            ethQty = srcAmt;
        } else {
            IERC20 tokenFunctions = IERC20(src);
            tokenFunctions.transferFrom(trader, address(this), srcAmt);
            ethQty = 0;
        }
    }

}