pragma solidity ^0.5.0;

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function totalSupply() external view returns (uint256);
    function balanceOf(address who) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface UniswapFactory {
    // Get Exchange and Token Info
    function getExchange(address token) external view returns (address exchange);
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
    function totalSupply() external view returns (uint);
}


contract Helper {

    /**
     * @dev get Uniswap Proxy address
     */
    function getAddressUniFactory() public pure returns (address factory) {
        factory = 0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95;
        // factory = 0xf5D915570BC477f9B8D6C0E980aA81757A3AaC36; // Rinkeby
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
     * @dev gets ETH & token balance
     * @param src is the token being sold
     * @return ethBal - if not erc20, eth balance
     * @return tknBal - if not eth, erc20 balance
     */
    function getBal(address src, address _owner) internal view returns (uint, uint) {
        uint tknBal = IERC20(src).balanceOf(address(_owner));
        return (address(_owner).balance, tknBal);
    }

    /**
     * @dev setting allowance to kyber for the "user proxy" if required
     * @param token is the token address
     */
    function setApproval(address token, uint srcAmt, address to) internal {
        IERC20 erc20Contract = IERC20(token);
        uint tokenAllowance = erc20Contract.allowance(address(this), to);
        if (srcAmt > tokenAllowance) {
            erc20Contract.approve(to, 2**255);
        }
    }
    
}


contract Pool is Helper {

    event LogAddLiquidity(
        address token,
        uint tokenAmt,
        uint ethAmt,
        uint poolTokenMinted,
        address beneficiary
    );

    event LogRemoveLiquidity(
        address token,
        uint tokenReturned,
        uint ethReturned,
        uint poolTokenBurned,
        address beneficiary
    );

    event LogShutPool(
        address token,
        uint tokenReturned,
        uint ethReturned,
        uint poolTokenBurned,
        address beneficiary
    );

    /**
     * @dev Uniswap's pool basic details
     * @param token token address to get pool. Eg:- DAI address, MKR address, etc
     * @param poolAddress Uniswap pool's address
     * @param totalSupply total supply of pool token
     * @param ethReserve Total ETH balance of uniswap's pool
     * @param tokenReserve Total Token balance of uniswap's pool
     */
    function poolDetails(
        address token
    ) public view returns (
        address poolAddress,
        uint totalSupply,
        uint ethReserve,
        uint tokenReserve
    )
    {
        poolAddress = getAddressPool(token);
        totalSupply = IERC20(poolAddress).totalSupply();
        (ethReserve, tokenReserve) = getBal(token, poolAddress);
    }

    /**
     * @dev to add liquidity in pool. Payable function token qty to deposit is decided as per the ETH sent by the user
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
            uint(1),
            tokenToDeposit,
            uint(1899063809) // 6th March 2030 GMT // no logic
        );
        emit LogAddLiquidity(
            token,
            tokenToDeposit,
            msg.value,
            tokensMinted,
            msg.sender
        );
    }

    /**
     * @dev to remove liquidity from pool. ETH and token quantity is decided as per the exchange token qty to burn
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
        emit LogRemoveLiquidity(
            token,
            tokenReturned,
            ethReturned,
            amount,
            msg.sender
        );
    }

    /**
     * @dev to remove all of the user's liquidity from pool. ETH and token quantity is decided as per the exchange token qty to burn
     * @param token ERC20 address of Uniswap's pool (eg:- DAI address, MKR address, etc)
     */
    function shut(address token) public returns (uint ethReturned, uint tokenReturned) {
        address poolAddr = getAddressPool(token);
        uint userPoolBal = IERC20(poolAddr).balanceOf(address(this));

        setApproval(poolAddr, userPoolBal, poolAddr);
        (ethReturned, tokenReturned) = UniswapPool(poolAddr).removeLiquidity(
            userPoolBal,
            uint(1),
            uint(1),
            uint(1899063809) // 6th March 2030 GMT // no logic
        );
        address(msg.sender).transfer(ethReturned);
        IERC20(token).transfer(msg.sender, tokenReturned);
        emit LogShutPool(
            token,
            tokenReturned,
            ethReturned,
            userPoolBal,
            msg.sender
        );
    }

}


contract InstaUniswapPool is Pool {

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