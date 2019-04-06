pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

interface AddressRegistry {
    function getAddr(string calldata name) external view returns (address);
}

interface Kyber {
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

contract helper is Registry {
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

    // approve to Kyber Proxy contract
    function _approveKyber(address token) internal returns (bool) {
        address kyberProxy = _getAddress("kyber");
        IERC20 tokenFunctions = IERC20(token);
        return tokenFunctions.approve(kyberProxy, uint(0 - 1));
    }

    // Check Allowance to Kyber Proxy contract
    function _allowanceKyber(address token) internal view returns (uint) {
        address kyberProxy = _getAddress("kyber");
        IERC20 tokenFunctions = IERC20(token);
        return tokenFunctions.allowance(address(this), kyberProxy);
    }

    // Check allowance, if not approve
    function _allowanceApproveKyber(address token) internal returns (bool) {
        uint allowanceGiven = _allowanceKyber(token);
        if (allowanceGiven == 0) {
            return _approveKyber(token);
        } else {
            return true;
        }
    }
}

contract Trade is helper {
    using SafeMath for uint;

    event KyberTrade(address src, uint srcAmt, address dest, uint destAmt, address beneficiary, uint minConversionRate, address affiliate);

    function getExpectedRateKyber(address src, address dest, uint srcAmt) public view returns (uint, uint) {
        Kyber kyberFunctions = Kyber(_getAddress("kyber"));
        return kyberFunctions.getExpectedRate(src, dest, srcAmt);
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

        if (src != eth) {
            _allowanceApproveKyber(src);
        }

        // Interacting with Kyber Proxy Contract
        Kyber kyberFunctions = Kyber(_getAddress("kyber"));
        tokensBought = kyberFunctions.trade.value(ethQty)(src, srcAmt, dest, msg.sender, uint(0 - 1), minDestAmt, _getAddress("admin"));

        emit KyberTrade(src, srcAmt, dest, tokensBought, msg.sender, minDestAmt, _getAddress("admin"));

    }

    /**
     * @dev Kyber's trade when token to sell Amount fixed
     * @param src - Token address to sell (for ETH it's "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
     * @param maxSrcAmt - max amount of token for sell (slippage)
     * @param dest - Token address to buy (for ETH it's "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
     * @param destAmt - amount of token to buy
    */
    function tradeDestKyber(
        address src, // token to sell
        uint maxSrcAmt, // amount of token for sell
        address dest, // token to buy
        uint destAmt // minimum slippage rate
    ) public payable returns (uint tokensBought) {
        address eth = _getAddress("eth");
        uint ethQty = _getToken(msg.sender, src, maxSrcAmt, eth);

        if (src != eth) {
            _allowanceApproveKyber(src);
        }

        // Interacting with Kyber Proxy Contract
        Kyber kyberFunctions = Kyber(_getAddress("kyber"));
        tokensBought = kyberFunctions.trade.value(ethQty)(src, maxSrcAmt, dest, msg.sender, destAmt, destAmt - 1, _getAddress("admin"));

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

        emit KyberTrade(src, maxSrcAmt, dest, tokensBought, msg.sender, destAmt, _getAddress("admin"));

    }

}


contract InstaKyber is Trade {
    constructor(address rAddr) public {
        addressRegistry = rAddr;
    }

    function() external payable {}
}
