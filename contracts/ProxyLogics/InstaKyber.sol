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

    address public eth; // 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
    address public kyber; // Kyber Proxy
    address public admin; // InstaDApp Kyber Registered Admin

    uint public maxCap = 2**255;

    /**
     * @dev fetching token from the trader if ERC20
     * @param trader is the trader
     * @param src is the token which is being sold
     * @param srcAmt is the amount of token being sold
     */
    function getToken(address trader, address src, uint srcAmt) internal returns (uint ethQty) {
        if (src == eth) {
            require(msg.value == srcAmt, "not-enough-src");
            ethQty = srcAmt;
        } else {
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
        tokenCall.approve(kyber, maxCap);
    }

    /**
     * @dev configuring token approval with user proxy
     * @param token is the token
     * @param spender is the user proxy
     */
    function manageApproval(address token, address spender, uint srcAmt) internal view returns (uint) {
        IERC20 tokenCall = IERC20(token);
        uint tokenAllowance = tokenCall.allowance(address(this), kyber);
        if (srcAmt > tokenAllowance) {
            setApproval(token);
        }
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
    ) internal view returns (
        uint expectedRate,
        uint slippageRate
    ) 
    {
        KyberInterface swapCall = KyberInterface(kyber);
        (expectedRate, slippageRate) = swapCall.getExpectedRate(src, dest, srcAmt);
        slippageRate = (slippageRate / 97) * 99; // changing slippage rate upto 99%
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

        KyberInterface swapCall = KyberInterface(kyber);
        destAmt = swapCall.trade.value(ethQty)(
            src,
            srcAmt,
            dest,
            msg.sender,
            maxDestAmt,
            slippageRate,
            admin
        );

        emit LogTrade(
            0,
            src,
            srcAmt,
            dest,
            destAmt,
            msg.sender,
            slippageRate,
            admin
        );

    }

    /**
     * @dev selling token where srcAmt is fixed
     * @param src - token to sell
     * @param srcAmt - token amount to sell
     * @param dest - token to buy
     */
    function sell(
        address src,
        address dest,
        uint srcAmt
    ) public payable returns (uint destAmt)
    {
        uint ethQty = getToken(msg.sender, src, srcAmt);
        (, uint slippageRate) = getExpectedRate(src, dest, srcAmt);

        KyberInterface swapCall = KyberInterface(kyber);
        destAmt = swapCall.trade.value(ethQty)(
            src,
            srcAmt,
            dest,
            msg.sender,
            maxCap,
            slippageRate,
            admin
        );

        emit LogTrade(
            1,
            src,
            srcAmt,
            dest,
            destAmt,
            msg.sender,
            slippageRate,
            admin
        );

        // maxDestAmt usecase implementated on user proxy
        if (src == eth && address(this).balance > 0) {
            msg.sender.transfer(address(this).balance);
        } else if (src != eth) {
            IERC20 srcTkn = IERC20(src);
            uint srcBal = srcTkn.balanceOf(address(this));
            if (srcBal > 0) {
                srcTkn.transfer(msg.sender, srcBal);
            }
        }

    }

}


contract InstaTrade is Swap {

    /**
     * @dev setting up variables on deployment
     */
    constructor(address _eth, address _kyber, address _admin) public {
        eth = _eth; // 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
        kyber = _kyber; // 0x818E6FECD516Ecc3849DAf6845e3EC868087B755
        admin = _admin;
    }

}