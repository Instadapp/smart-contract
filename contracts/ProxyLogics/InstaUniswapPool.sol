pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

interface UniswapFactory {
    // Get Exchange and Token Info
    function getExchange(address token) external view returns (address exchange);
    function getToken(address exchange) external view returns (address token);
}

interface UniswapPool {
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
    function totalSupply() external returns (uint256);
}


contract Helper {

    /**
     * @dev get Uniswap Proxy address
     */
    function getAddressUniFactory() public pure returns (address factory) {
        factory = 0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95;
    }

    // Get Uniswap's Exchange address from Factory Contract
    function getAddressPool(address _token) public view returns (address) {
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
        uint tknBal = IERC20(src).balanceOf(address(_owner));
        return (address(_owner).balance, tknBal);
    }

    /**
     * @dev setting allowance to kyber for the "user proxy" if required
     * @param token is the token address
     */
    function setApproval(address token, uint srcAmt, address to) internal {
        uint tokenAllowance = IERC20(token).allowance(address(this), to);
        if (srcAmt > tokenAllowance) {
            IERC20(token).approve(to, 2**255);
        }
    }
    
}


contract InstaUniswapPool is Helper {

    /**
     * @title Uniswap's pool basic details
     * @param token token address to get pool. Eg:- DAI address, MKR address, etc
     * @param poolAddress Uniswap pool's address
     * @param name name of pool token
     * @param symbol symbol of pool token
     * @param decimals decimals of pool token
     * @param totalSupply total supply of pool token
     * @param ethReserve Total ETH balance of uniswap's pool
     * @param tokenReserve Total Token balance of uniswap's pool
     */
    function poolDetails(
        address token
    ) public view returns (
        address poolAddress,
        bytes32 name,
        bytes32 symbol,
        uint256 decimals,
        uint totalSupply,
        uint ethReserve,
        uint tokenReserve
    )
    {
        UniswapPool uniswapExchange = UniswapPool(poolAddress);
        poolAddress = getAddressPool(token);
        name = uniswapExchange.name();
        symbol = uniswapExchange.symbol();
        decimals = uniswapExchange.decimals();
        totalSupply = uniswapExchange.totalSupply();
        (ethReserve, tokenReserve) = getBal(token, poolAddress);
    }

    /**
     * @title to add liquidity in pool
     * @dev payable function token qty to deposit is decided as per the ETH sent by the user
     * @param token ERC20 address of Uniswap's pool (eg:- DAI address, MKR address, etc)
     * @param maxDepositedTokens Max token to be deposited
     */
    function addLiquidity(address token, uint maxDepositedTokens) public payable returns (uint256 tokensMinted) {
        address poolAddr = getAddressPool(token);
        (uint ethReserve, uint tokenReserve) = getBal(token, poolAddr);
        uint tokenToDeposit = msg.value * tokenReserve / ethReserve + 1;
        require(tokenToDeposit < maxDepositedTokens, "Token to deposit is greater than Max token to Deposit");
        IERC20(token).transferFrom(msg.sender, address(this), tokenToDeposit);
        setApproval(token, tokenToDeposit, poolAddr);
        tokensMinted = UniswapPool(poolAddr).addLiquidity.value(msg.value)(
            uint(0),
            tokenToDeposit,
            uint(1899063809) // 6th March 2030 GMT // no logic
        );
    }

    /**
     * @title to remove liquidity from pool
     * @dev ETH and token quantity is decided as per the exchange token qty to burn
     * @param token ERC20 address of Uniswap's pool (eg:- DAI address, MKR address, etc)
     * @param amount Uniswap pool's ERC20 token QTY to burn
     * @param minEth Min ETH user to be returned
     * @param minTokens Min Tokens to be returned
     */
    function removeLiquidity(
        address token,
        uint amount,
        uint minEth,
        uint minTokens
    ) public returns (uint ethReturned, uint tokenReturned)
    {
        address poolAddr = getAddressPool(token);
        setApproval(poolAddr, amount, poolAddr);
        (ethReturned, tokenReturned) = UniswapPool(poolAddr).removeLiquidity(
            amount,
            minEth,
            minTokens,
            uint(1899063809) // 6th March 2030 GMT // no logic
        );
        address(msg.sender).transfer(ethReturned);
        IERC20(token).transfer(msg.sender, tokenReturned);
    }

}