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


interface IERC20 {
    function balanceOf(address who) external view returns (uint256);
    function allowance(address _owner, address _spender) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface KyberInterface {
    function trade(
        address src,
        uint srcAmount,
        address dest,
        address destAddress,
        uint maxDestAmount,
        uint minConversionRate,
        address walletId
    ) external payable returns (uint);

    function getExpectedRate(
        address src,
        address dest,
        uint srcQty
    ) external view returns (uint, uint);
}


contract Helper {

    using SafeMath for uint;
    using SafeMath for uint256;

    /**
     * @dev get ethereum address for trade
     */
    function getAddressETH() public view returns (address eth) {
        eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }

    /**
     * @dev get kyber proxy address
     */
    function getAddressKyber() public view returns (address kyber) {
        kyber = 0x692f391bCc85cefCe8C237C01e1f636BbD70EA4D;
    }

    /**
     * @dev get admin address
     */
    function getAddressAdmin() public view returns (address admin) {
        admin = 0x7284a8451d9a0e7Dc62B3a71C0593eA2eC5c5638;
    }

    /**
     * @dev get fees to trade // 200 => 0.2%
     */
    function getUintFees() public view returns (uint fees) {
        fees = 200;
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
        KyberInterface swapCall = KyberInterface(getAddressKyber());
        (expectedRate, slippageRate) = swapCall.getExpectedRate(src, dest, srcAmt);
        slippageRate = (slippageRate / 97) * 99; // changing slippage rate upto 99%
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
            IERC20 tokenCall = IERC20(src);
            tokenCall.transferFrom(trader, address(this), srcAmt);
        }
    }

    /**
     * @dev setting allowance to kyber for the "user proxy" if required
     * @param token is the token address
     */
    function setApproval(address token) internal returns (uint) {
        IERC20 tokenCall = IERC20(token);
        tokenCall.approve(getAddressKyber(), 2**255);
    }

    /**
     * @dev configuring token approval with user proxy
     * @param token is the token
     */
    function manageApproval(address token, uint srcAmt) internal returns (uint) {
        IERC20 tokenCall = IERC20(token);
        uint tokenAllowance = tokenCall.allowance(address(this), getAddressKyber());
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
        uint what,
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
        uint maxDestAmt
    ) public payable returns (uint destAmt)
    {
        uint ethQty = getToken(msg.sender, src, srcAmt);
        (, uint slippageRate) = getExpectedRate(src, dest, srcAmt);

        KyberInterface swapCall = KyberInterface(getAddressKyber());
        destAmt = swapCall.trade.value(ethQty)(
            src,
            srcAmt,
            dest,
            msg.sender,
            maxDestAmt,
            slippageRate,
            getAddressAdmin()
        );

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
        uint srcAmt
    ) public payable returns (uint destAmt)
    {
        uint ethQty = getToken(msg.sender, src, srcAmt);
        (, uint slippageRate) = getExpectedRate(src, dest, srcAmt);

        KyberInterface swapCall = KyberInterface(getAddressKyber());
        destAmt = swapCall.trade.value(ethQty)(
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

        // maxDestAmt usecase implementated on user proxy
        if (src == getAddressETH() && address(this).balance > 0) {
            msg.sender.transfer(address(this).balance);
        } else if (src != getAddressETH()) {
            IERC20 srcTkn = IERC20(src);
            uint srcBal = srcTkn.balanceOf(address(this));
            if (srcBal > 0) {
                srcTkn.transfer(msg.sender, srcBal);
            }
        }

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