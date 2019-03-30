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


contract KyberInterface {
    function trade(
        address src,
        uint srcAmount,
        address dest,
        address destAddress,
        uint maxDestAmount,
        uint minConversionRate,
        address walletId
        ) public payable returns (uint);

    function getExpectedRate(
        address src,
        address dest,
        uint srcQty
        ) public view returns (uint, uint);
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
            manageApproval(src, srcAmt);
            IERC20(src).transferFrom(trader, address(this), srcAmt);
        }
    }

    /**
     * @dev setting allowance to kyber for the "user proxy" if required
     * @param token is the token address
     */
    function setApproval(address token) internal returns (uint) {
        IERC20(token).approve(getAddressKyber(), 2**255);
    }

    /**
     * @dev configuring token approval with user proxy
     * @param token is the token
     */
    function manageApproval(address token, uint srcAmt) internal returns (uint) {
        uint tokenAllowance = IERC20(token).allowance(address(this), getAddressKyber());
        if (srcAmt > tokenAllowance) {
            setApproval(token);
        }
    }
    
}


contract Swap is Helper {

    /**
     * @param what 0 for BUY & 1 for SELL
     */
    event LogTrade(
        uint what, // 0 for BUY & 1 for SELL
        address src,
        uint srcAmt,
        address dest,
        uint destAmt,
        address beneficiary,
        uint minConversionRate,
        address affiliate
    );

    /**
     * @dev buying token where destAmt is fixed
     * @param src - token to sell
     * @param dest - token to buy
     * @param srcAmt - token amount to sell
     * @param maxDestAmt is the max amount of token to be bought
     */
    function buy(
        address src,
        address dest,
        uint srcAmt,
        uint maxDestAmt,
        uint slippageRate
    ) public payable returns (uint destAmt)
    {
        uint ethQty = getToken(msg.sender, src, srcAmt);

        destAmt = KyberInterface(getAddressKyber()).trade.value(ethQty)(
            src,
            srcAmt,
            dest,
            msg.sender,
            maxDestAmt,
            slippageRate,
            getAddressAdmin()
        );

        // maxDestAmt usecase implementated on user proxy
        if (address(this).balance > 0) {
            msg.sender.transfer(address(this).balance);
        } else if (src != getAddressETH()) {
            IERC20 srcTkn = IERC20(src);
            uint srcBal = srcTkn.balanceOf(address(this));
            if (srcBal > 0) {
                srcTkn.transfer(msg.sender, srcBal);
            }
        }

        emit LogTrade(
            0,
            src,
            srcAmt,
            dest,
            destAmt,
            msg.sender,
            slippageRate,
            getAddressAdmin()
        );

    }

    /**
     * @dev selling token where srcAmt is fixed
     * @param src - token to sell
     * @param dest - token to buy
     * @param srcAmt - token amount to sell
     */
    function sell(
        address src,
        address dest,
        uint srcAmt,
        uint slippageRate
    ) public payable returns (uint destAmt)
    {
        uint ethQty = getToken(msg.sender, src, srcAmt);

        destAmt = KyberInterface(getAddressKyber()).trade.value(ethQty)(
            src,
            srcAmt,
            dest,
            msg.sender,
            2**255,
            slippageRate,
            getAddressAdmin()
        );

        emit LogTrade(
            1,
            src,
            srcAmt,
            dest,
            destAmt,
            msg.sender,
            slippageRate,
            getAddressAdmin()
        );

    }

}


contract InstaTrade is Swap {

    uint public version;
    
    /**
     * @dev setting up variables on deployment
     * 1...2...3 versioning in each subsequent deployments
     */
    constructor(uint _version) public {
        version = _version;
    }

}