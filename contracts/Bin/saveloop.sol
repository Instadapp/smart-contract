/**
 *Submitted for verification at Etherscan.io on 2019-06-20
*/

pragma solidity ^0.5.0;

contract TokenInterface {
    function allowance(address, address) public returns (uint);
    function balanceOf(address) public returns (uint);
    function approve(address, uint) public;
    function transfer(address, uint) public returns (bool);
    function transferFrom(address, address, uint) public returns (bool);
    function deposit() public payable;
    function withdraw(uint) public;
}

contract PipInterface {
    function read() public returns (bytes32);
}

contract PepInterface {
    function peek() public returns (bytes32, bool);
}

contract VoxInterface {
    function par() public returns (uint);
}

contract TubInterface {
    event LogNewCup(address indexed lad, bytes32 cup);

    function open() public returns (bytes32);
    function join(uint) public;
    function exit(uint) public;
    function lock(bytes32, uint) public;
    function free(bytes32, uint) public;
    function draw(bytes32, uint) public;
    function wipe(bytes32, uint) public;
    function give(bytes32, address) public;
    function shut(bytes32) public;
    function bite(bytes32) public;
    function cups(bytes32) public returns (address, uint, uint, uint);
    function gem() public returns (TokenInterface);
    function gov() public returns (TokenInterface);
    function skr() public returns (TokenInterface);
    function sai() public returns (TokenInterface);
    function vox() public returns (VoxInterface);
    function ask(uint) public returns (uint);
    function mat() public returns (uint);
    function chi() public returns (uint);
    function ink(bytes32) public returns (uint);
    function tab(bytes32) public returns (uint);
    function rap(bytes32) public returns (uint);
    function per() public returns (uint);
    function pip() public returns (PipInterface);
    function pep() public returns (PepInterface);
    function tag() public returns (uint);
    function drip() public;
    function lad(bytes32 cup) public view returns (address);
    function bid(uint wad) public view returns (uint);
}


interface ERC20 {
    function totalSupply() external view returns (uint supply);
    function balanceOf(address _owner) external view returns (uint balance);
    function transfer(address _to, uint _value) external returns (bool success);
    function transferFrom(address _from, address _to, uint _value) external returns (bool success);
    function approve(address _spender, uint _value) external returns (bool success);
    function allowance(address _owner, address _spender) external view returns (uint remaining);
    function decimals() external view returns(uint digits);
    function allocateTo(address recipient, uint256 value) external;
    event Approval(address indexed _owner, address indexed _spender, uint _value);
}


interface ExchangeInterface {
    function swapEtherToToken (uint _ethAmount, address _tokenAddress, uint _maxAmount) payable external returns(uint, uint);
    function swapTokenToEther (address _tokenAddress, uint _amount, uint _maxAmount) external returns(uint);

    function getExpectedRate(address src, address dest, uint srcQty) external
        returns (uint expectedRate, uint slippageRate);
}

contract DSMath {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }
    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    function min(uint x, uint y) internal pure returns (uint z) {
        return x <= y ? x : y;
    }
    function max(uint x, uint y) internal pure returns (uint z) {
        return x >= y ? x : y;
    }
    function imin(int x, int y) internal pure returns (int z) {
        return x <= y ? x : y;
    }
    function imax(int x, int y) internal pure returns (int z) {
        return x >= y ? x : y;
    }

    uint constant WAD = 10 ** 18;
    uint constant RAY = 10 ** 27;

    function wmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }
    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), RAY / 2) / RAY;
    }
    function wdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, WAD), y / 2) / y;
    }
    function rdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, RAY), y / 2) / y;
    }

    // This famous algorithm is called "exponentiation by squaring"
    // and calculates x^n with x as fixed-point and n as regular unsigned.
    //
    // It's O(log n), instead of O(n) for naive repeated multiplication.
    //
    // These facts are why it works:
    //
    //  If n is even, then x^n = (x^2)^(n/2).
    //  If n is odd,  then x^n = x * x^(n-1),
    //   and applying the equation for even x gives
    //    x^n = x * (x^2)^((n-1) / 2).
    //
    //  Also, EVM division is flooring and
    //    floor[(n-1) / 2] = floor[n / 2].
    //
    function rpow(uint x, uint n) internal pure returns (uint z) {
        z = n % 2 != 0 ? x : RAY;

        for (n /= 2; n != 0; n /= 2) {
            x = rmul(x, x);

            if (n % 2 != 0) {
                z = rmul(z, x);
            }
        }
    }
}

contract SaverLogger {
    event Repay(uint indexed cdpId, address indexed owner, uint collateralAmount, uint daiAmount);
    event Boost(uint indexed cdpId, address indexed owner, uint daiAmount, uint collateralAmount);

    function LogRepay(uint _cdpId, address _owner, uint _collateralAmount, uint _daiAmount) public {
        emit Repay(_cdpId, _owner, _collateralAmount, _daiAmount);
    }

    function LogBoost(uint _cdpId, address _owner, uint _daiAmount, uint _collateralAmount) public {
        emit Boost(_cdpId, _owner, _daiAmount, _collateralAmount);
    }
}

/// @title SaverProxy implements advanced dashboard features repay/boost
contract SaverProxy is DSMath {
    //KOVAN
    // address public constant WETH_ADDRESS = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;
    // address public constant DAI_ADDRESS = 0xC4375B7De8af5a38a93548eb8453a498222C4fF2;
    // address public constant MKR_ADDRESS = 0xAaF64BFCC32d0F15873a02163e7E500671a4ffcD;
    // address public constant VOX_ADDRESS = 0xBb4339c0aB5B1d9f14Bd6e3426444A1e9d86A1d9;
    // address public constant PETH_ADDRESS = 0xf4d791139cE033Ad35DB2B2201435fAd668B1b64;
    // address public constant KYBER_WRAPPER = 0x82CD6436c58A65E2D4263259EcA5843d3d7e0e65;
    // address public constant TUB_ADDRESS = 0xa71937147b55Deb8a530C7229C442Fd3F31b7db2;
    // address public constant ETHER_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // address public constant KYBER_WRAPPER = 0x5595930d576Aedf13945C83cE5aaD827529A1310;
    // address public constant UNISWAP_WRAPPER = 0x5595930d576Aedf13945C83cE5aaD827529A1310;
    // address public constant ETH2DAI_WRAPPER = 0x823cde416973a19f98Bb9C96d97F4FE6C9A7238B;
    // address public constant WALLET_ID = 0x54b44C6B18fc0b4A1010B21d524c338D1f8065F6;
    
    // MAINNET
    address public constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant DAI_ADDRESS = 0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359;
    address public constant MKR_ADDRESS = 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2;
    address public constant VOX_ADDRESS = 0x9B0F70Df76165442ca6092939132bBAEA77f2d7A;
    address public constant PETH_ADDRESS = 0xf53AD2c6851052A81B42133467480961B2321C09;
    address public constant TUB_ADDRESS = 0x448a5065aeBB8E423F0896E6c5D525C040f59af3;
    address public constant ETHER_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant KYBER_WRAPPER = 0xAae7ba823679889b12f71D1f18BEeCBc69E62237;
    address public constant LOGGER_ADDRESS = 0xeCf88e1ceC2D2894A0295DB3D86Fe7CE4991E6dF;
    
    address public constant UNISWAP_WRAPPER = 0x0aa70981311D60a9521C99cecFDD68C3E5a83B83;
    address public constant ETH2DAI_WRAPPER = 0xd7BBB1777E13b6F535Dec414f575b858ed300baF;
    address public constant WALLET_ID = 0x322d58b9E75a6918f7e7849AEe0fF09369977e08;
    
    uint public constant SERVICE_FEE = 400; // 0.25% Fee
    
      /// @notice Withdraws Eth collateral, swaps Eth -> Dai with Kyber, and pays back the debt in Dai
    /// @dev If _buyMkr is false user needs to have MKR tokens and approve his DSProxy
    /// @param _cup Id of the CDP
    /// @param _amount Amount of Eth to sell
    /// @param _minPrice Minimum acaptable ETH/DAI price
    function repay(bytes32 _cup, uint _amount, uint _minPrice, uint _exchangeType) public {
        address exchangeWrapper;
        uint ethDaiPrice;

        (exchangeWrapper, ethDaiPrice) = getBestPrice(_amount, ETHER_ADDRESS, DAI_ADDRESS, _exchangeType);

        require(ethDaiPrice > _minPrice, "Slippage hit");

        TubInterface tub = TubInterface(TUB_ADDRESS);

        approveTub(DAI_ADDRESS);
        approveTub(MKR_ADDRESS);
        approveTub(PETH_ADDRESS);
        approveTub(WETH_ADDRESS);

        uint startingRatio = getRatio(tub, _cup);

        if (_amount > maxFreeCollateral(tub, _cup)) {
            _amount = maxFreeCollateral(tub, _cup);
        }

        withdrawEth(tub, _cup, _amount);

        uint daiAmount = wmul(_amount, ethDaiPrice);
        uint cdpWholeDebt = getDebt(tub, _cup);

        uint mkrAmount = stabilityFeeInMkr(tub, _cup, sub(daiAmount, daiAmount / SERVICE_FEE));

        if (daiAmount > cdpWholeDebt) {
            mkrAmount = stabilityFeeInMkr(tub, _cup, cdpWholeDebt);
        }

        uint ethFee = wdiv(mkrAmount, estimatedMkrPrice(_amount));

        uint change;
        (, change) = ExchangeInterface(KYBER_WRAPPER).swapEtherToToken.
                        value(ethFee)(ethFee, MKR_ADDRESS, mkrAmount);


        _amount = sub(_amount, sub(ethFee, change));

        (daiAmount, ) = ExchangeInterface(exchangeWrapper).swapEtherToToken.
                            value(_amount)(_amount, DAI_ADDRESS, uint(-1));

         // Take a fee from the user in dai
         daiAmount = sub(daiAmount, takeFee(daiAmount));
        
        if (daiAmount > cdpWholeDebt) {
            tub.wipe(_cup, cdpWholeDebt);
            ERC20(DAI_ADDRESS).transfer(msg.sender, sub(daiAmount, cdpWholeDebt));
        } else {
            tub.wipe(_cup, daiAmount);
            require(getRatio(tub, _cup) > startingRatio, "ratio must be better off at the end");
        }

        SaverLogger(LOGGER_ADDRESS).LogRepay(uint(_cup), msg.sender, _amount, daiAmount);
    }

    /// @notice Boost will draw Dai, swap Dai -> Eth on kyber, and add that Eth to the CDP
    /// @dev Amount must be less then the max. amount available Dai to generate
    /// @param _cup Id of the CDP
    /// @param _amount Amount of Dai to sell
    /// @param _minPrice Minimum acaptable ETH/DAI price
    function boost(bytes32 _cup, uint _amount, uint _minPrice, uint _exchangeType) public {
        address exchangeWrapper;
        uint daiEthPrice;

        (exchangeWrapper, daiEthPrice) = getBestPrice(_amount, DAI_ADDRESS, ETHER_ADDRESS, _exchangeType);

        require(wdiv(1000000000000000000, daiEthPrice) < _minPrice, "Slippage hit");

        TubInterface tub = TubInterface(TUB_ADDRESS);

        approveTub(WETH_ADDRESS);
        approveTub(PETH_ADDRESS);
        approveTub(DAI_ADDRESS);
        
        uint maxAmount = maxFreeDai(tub, _cup);

        if (_amount > maxAmount) {
            _amount = maxAmount;
        }

        uint startingCollateral = tub.ink(_cup);
        
        tub.draw(_cup, _amount);

        // Take a fee from the user in dai
        _amount = sub(_amount, takeFee(_amount));
        
        uint ethAmount = swapDaiAndLockEth(tub, _cup, _amount, exchangeWrapper);

        require(tub.ink(_cup) > startingCollateral, "collateral must be bigger than starting point");
        
        SaverLogger(LOGGER_ADDRESS).LogBoost(uint(_cup), msg.sender, _amount, ethAmount);
    }

    /// @notice Max. amount of collateral available to withdraw
    /// @param _tub Tub interface
    /// @param _cup Id of the CDP
    function maxFreeCollateral(TubInterface _tub, bytes32 _cup) public returns (uint) {
        return sub(_tub.ink(_cup), wdiv(wmul(wmul(_tub.tab(_cup), rmul(_tub.mat(), WAD)),
                VoxInterface(VOX_ADDRESS).par()), _tub.tag())) - 1;
    }
    
    /// @notice Max. amount of Dai available to generate
    /// @param _tub Tub interface
    /// @param _cup Id of the CDP
    function maxFreeDai(TubInterface _tub, bytes32 _cup) public returns (uint) {
        return sub(wdiv(rmul(_tub.ink(_cup), _tub.tag()), rmul(_tub.mat(), WAD)), _tub.tab(_cup)) - 1;
    }

    /// @notice Stability fee amount in Mkr
    /// @param _tub Tub interface
    /// @param _cup Id of the CDP
    /// @param _daiRepay Amount of dai we are repaying
    function stabilityFeeInMkr(TubInterface _tub, bytes32 _cup, uint _daiRepay) public returns (uint) {
        bytes32 mkrPrice;
        bool ok;

        uint feeInDai = rmul(_daiRepay, rdiv(_tub.rap(_cup), _tub.tab(_cup)));

        (mkrPrice, ok) = _tub.pep().peek();

        return wdiv(feeInDai, uint(mkrPrice));
    }
    
    /// @notice Helper function which swaps Dai for Eth and adds the collateral to the CDP
    /// @param _tub Tub interface
    /// @param _cup Id of the CDP
    /// @param _daiAmount Amount of Dai to swap for Eth
    function swapDaiAndLockEth(TubInterface _tub, bytes32 _cup, uint _daiAmount, address _exchangeWrapper) internal returns(uint) {

        ERC20(DAI_ADDRESS).transfer(_exchangeWrapper, _daiAmount);

        uint ethAmount = ExchangeInterface(_exchangeWrapper).swapTokenToEther(DAI_ADDRESS, _daiAmount, uint(-1));
        
        _tub.gem().deposit.value(ethAmount)();

        uint ink = sub(rdiv(ethAmount, _tub.per()), 1);
        
        _tub.join(ink);

        _tub.lock(_cup, ink);
        
        return ethAmount;
    }

    /// @notice Approve a token if it's not already approved
    /// @param _tokenAddress Address of the ERC20 token we want to approve
    function approveTub(address _tokenAddress) internal {
        if (ERC20(_tokenAddress).allowance(msg.sender, _tokenAddress) < (uint(-1) / 2)) {
            ERC20(_tokenAddress).approve(TUB_ADDRESS, uint(-1));
        }
    }

    /// @notice Returns the current collaterlization ratio for the CDP
    /// @param _tub Tub interface
    /// @param _cup Id of the CDP
    function getRatio(TubInterface _tub, bytes32 _cup) internal returns(uint) {
        return (wdiv(rmul(rmul(_tub.ink(_cup), _tub.tag()), WAD), _tub.tab(_cup)));
    }

    /// @notice Helper function which withdraws collateral from CDP
    /// @param _tub Tub interface
    /// @param _cup Id of the CDP
    /// @param _ethAmount Amount of Eth to withdraw
    function withdrawEth(TubInterface _tub, bytes32 _cup, uint _ethAmount) internal {
        uint ink = rdiv(_ethAmount, _tub.per());
        _tub.free(_cup, ink);
        
        _tub.exit(ink);
        _tub.gem().withdraw(_ethAmount);
    }

    /// @notice Takes a feePercentage and sends it to wallet
    /// @param _amount Dai amount of the whole trade
    /// @return feeAmount Amount in Dai owner earned on the fee
    function takeFee(uint _amount) internal returns (uint feeAmount) {
        feeAmount = _amount / SERVICE_FEE;
        ERC20(DAI_ADDRESS).transfer(WALLET_ID, feeAmount);
    }

    /// @notice Returns the best estimated price from 2 exchanges
    /// @param _amount Amount of source tokens you want to exchange
    /// @param _srcToken Address of the source token
    /// @param _destToken Address of the destination token
    /// @return (address, uint) The address of the best exchange and the exchange price
    function getBestPrice(uint _amount, address _srcToken, address _destToken, uint _exchangeType) internal returns (address, uint) {
        uint expectedRateKyber;
        uint expectedRateUniswap;
        uint expectedRateEth2Dai;

        (expectedRateKyber, ) = ExchangeInterface(KYBER_WRAPPER).getExpectedRate(_srcToken, _destToken, _amount);
        (expectedRateUniswap, ) = ExchangeInterface(UNISWAP_WRAPPER).getExpectedRate(_srcToken, _destToken, _amount);
        (expectedRateEth2Dai, ) = ExchangeInterface(ETH2DAI_WRAPPER).getExpectedRate(_srcToken, _destToken, _amount);

        if (_exchangeType == 1) {
            return (ETH2DAI_WRAPPER, expectedRateEth2Dai);
        }

        if (_exchangeType == 2) {
            return (KYBER_WRAPPER, expectedRateKyber);
        }

        if (_exchangeType == 3) {
            return (UNISWAP_WRAPPER, expectedRateUniswap);
        }

        if (expectedRateEth2Dai > expectedRateKyber && expectedRateEth2Dai > expectedRateUniswap) {
            return (ETH2DAI_WRAPPER, expectedRateEth2Dai);
        }

        if (expectedRateKyber > expectedRateUniswap && expectedRateKyber > expectedRateEth2Dai) {
            return (KYBER_WRAPPER, expectedRateKyber);
        }

        if (expectedRateUniswap > expectedRateKyber && expectedRateUniswap > expectedRateEth2Dai) {
            return (UNISWAP_WRAPPER, expectedRateUniswap);
        }
    }

    /// @notice Returns expected rate for Eth -> Dai conversion
    /// @param _amount Amount of Ether
    function estimatedDaiPrice(uint _amount) internal returns (uint expectedRate) {
        (expectedRate, ) = ExchangeInterface(KYBER_WRAPPER).getExpectedRate(ETHER_ADDRESS, DAI_ADDRESS, _amount);
    }

    /// @notice Returns expected rate for Dai -> Eth conversion
    /// @param _amount Amount of Dai
    function estimatedEthPrice(uint _amount) internal returns (uint expectedRate) {
        (expectedRate, ) = ExchangeInterface(KYBER_WRAPPER).getExpectedRate(DAI_ADDRESS, ETHER_ADDRESS, _amount);
    }

    /// @notice Returns expected rate for Eth -> Mkr conversion
    /// @param _amount Amount of Ether
    function estimatedMkrPrice(uint _amount) internal returns (uint expectedRate) {
        (expectedRate, ) = ExchangeInterface(KYBER_WRAPPER).getExpectedRate(ETHER_ADDRESS, MKR_ADDRESS, _amount);
    }

    /// @notice Returns current Dai debt of the CDP
    /// @param _tub Tub interface
    /// @param _cup Id of the CDP
    function getDebt(TubInterface _tub, bytes32 _cup) internal returns (uint debt) {
        ( , , debt, ) = _tub.cups(_cup);
    }
}