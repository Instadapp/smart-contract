pragma solidity ^0.5.0;


library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "Assertion Failed");
        return c;
    }
}


contract IERC20 {
    function balanceOf(address who) public view returns (uint256);
    function allowance(address _owner, address _spender) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    function approve(address spender, uint256 value) public returns (bool);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
}


contract UniswapFactory {
    // Get Exchange and Token Info
    function getExchange(address token) external view returns (address exchange);
    function getToken(address exchange) external view returns (address token);
}


// Solidity Interface
contract UniswapPool {
    // Address of ERC20 token sold on this exchange
    function tokenAddress() external view returns (address token);
    // Address of Uniswap Factory
    function factoryAddress() external view returns (address factory);
    // Provide Liquidity
    function addLiquidity(uint256 minLiquidity, uint256 maxTokens, uint256 deadline) external payable returns (uint256);
    // Remove Liquidity
    function removeLiquidity(
        uint256 amount,
        uint256 minEth,
        uint256 minTokens,
        uint256 deadline
        ) external returns (uint256, uint256);

    // ERC20 comaptibility for liquidity tokens
    function name() external returns (bytes32);
    function symbol() external returns (bytes32);
    function decimals() external returns (uint256);
    function transfer(address _to, uint256 _value) external returns (bool);
    function transferFrom(address _from, address _to, uint256 value) external returns (bool);
    function approve(address _spender, uint256 _value) external returns (bool);
    function allowance(address _owner, address _spender) external view returns (uint256);
    function balanceOf(address _owner) external view returns (uint256);
}


contract Helper {

    using SafeMath for uint;
    using SafeMath for uint256;

    /**
     * @dev get ethereum address for trade
     */
    function getAddressETH() public pure returns (address eth) {
        eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }

    /**
     * @dev get Uniswap Proxy address
     */
    function getAddressUniFactory() public pure returns (address factory) {
        factory = 0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95;
    }

    // Get Uniswap's Exchange address from Factory Contract
    function getExchangeAddress(address _token) public view returns (address) {
        return UniswapFactory(getAddressUniFactory()).getExchange(_token);
    }

    /**
     * @dev get admin address
     */
    function getAddressAdmin() public pure returns (address admin) {
        admin = 0x7284a8451d9a0e7Dc62B3a71C0593eA2eC5c5638;
    }

    /**
     * @dev get fees to trade // 200 => 0.2%
     */
    function getUintFees() public pure returns (uint fees) {
        fees = 200;
    }

    /**
     * @dev gets ETH & token balance
     * @param src is the token being sold
     * @return ethBal - if not erc20, eth balance
     * @return tknBal - if not eth, erc20 balance
     */
    function getBal(address src, address _owner) public view returns (uint, uint) {
        uint tknBal;
        if (src != getAddressETH()) {
            tknBal = IERC20(src).balanceOf(address(_owner));
        }
        return (address(_owner).balance, tknBal);
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
            manageApproval(src, srcAmt);
            IERC20(src).transferFrom(trader, address(this), srcAmt);
        }
    }

    /**
     * @dev setting allowance to kyber for the "user proxy" if required
     * @param token is the token address
     */
    function setApproval(address token, address exchangeAddr) internal {
        IERC20(token).approve(exchangeAddr, 2**255);
    }

    /**
     * @dev configuring token approval with user proxy
     * @param token is the token
     */
    function manageApproval(address token, uint srcAmt) internal returns (uint) {
        address exchangeAddr = getExchangeAddress(token);
        uint tokenAllowance = IERC20(token).allowance(address(this), exchangeAddr);
        if (srcAmt > tokenAllowance) {
            setApproval(token, exchangeAddr);
        }
    }
    
}


contract InstaUniswapPool is Helper {

    function addLiquidity(address token, uint maxDepositedTokens) public payable returns (uint256 tokensMinted) {
        address exchangeAddr = getExchangeAddress(token);
        (uint exchangeEthBal, uint exchangeTokenBal) = getBal(token, exchangeAddr);
        uint tokenToDeposit = msg.value * (exchangeTokenBal/exchangeEthBal);
        require(tokenToDeposit < maxDepositedTokens, "Token to deposit is greater than Max token to Deposit");
        manageApproval(token, tokenToDeposit);
        tokensMinted = UniswapPool(exchangeAddr).addLiquidity.value(msg.value)(
            uint(0),
            tokenToDeposit,
            uint(1899063809) // 6th March 2030 GMT // no logic
        );
    }

}