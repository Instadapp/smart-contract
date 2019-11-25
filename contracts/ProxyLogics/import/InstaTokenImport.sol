pragma solidity ^0.5.7;

interface ERC20Interface {
    function allowance(address, address) external view returns (uint);
    function balanceOf(address) external view returns (uint);
    function approve(address, uint) external;
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
}

interface ComptrollerInterface {
    function enterMarkets(address[] calldata cTokens) external returns (uint[] memory);
    function getAssetsIn(address account) external view returns (address[] memory);
}


contract DSMath {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, "math-not-safe");
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, "math-not-safe");
    }

    uint constant WAD = 10 ** 18;

    function wmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }
}


contract Helper is DSMath {

    /**
     * @dev get Compound Comptroller Address
     */
    function getComptrollerAddress() public pure returns (address troller) {
        troller = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    }

    function enterMarket(address[] memory cErc20) internal {
        ComptrollerInterface troller = ComptrollerInterface(getComptrollerAddress());
        address[] memory markets = troller.getAssetsIn(address(this));
        address[] memory toEnter = new address[](cErc20.length);
        uint count = 0;
        for (uint j = 0; j < cErc20.length; j++) {
            bool isEntered = false;
            for (uint i = 0; i < markets.length; i++) {
                if (markets[i] == cErc20[j]) {
                    isEntered = true;
                    break;
                }
            }
            if (!isEntered) {
                toEnter[count] = cErc20[j];
                count += 1;
            }
        }
        troller.enterMarkets(toEnter);
    }
}


contract ImportResolver is Helper {
    event LogTokensImport(address owner, uint percentage, address[] tokenAddr, uint[] tokenBalArr);
    event LogCTokensImport(address owner, uint percentage, address[] tokenAddr, uint[] tokenBalArr);

    function importTokens(uint toConvert, address[] memory tokenAddrArr) public {
        uint[] memory tokenBalArr = new uint[](tokenAddrArr.length);

         // transfer tokens to InstaDApp smart wallet from user wallet
        for (uint i = 0; i < tokenAddrArr.length; i++) {
            address erc20 = tokenAddrArr[i];
            ERC20Interface tknContract = ERC20Interface(erc20);
            uint tokenBal = tknContract.balanceOf(msg.sender);
            tokenBal = toConvert < 10**18 ? wmul(tokenBal, toConvert) : tokenBal;
            if (tokenBal > 0) {
                require(tknContract.transferFrom(msg.sender, address(this), tokenBal), "Allowance?");
            }
            tokenBalArr[i] = tokenBal;
        }

        emit LogTokensImport(
            msg.sender,
            toConvert,
            tokenAddrArr,
            tokenBalArr
        );
    }

    function importCTokens(uint toConvert, address[] memory ctokenAddrArr) public {
        uint[] memory tokenBalArr = new uint[](ctokenAddrArr.length);

         // transfer tokens to InstaDApp smart wallet from user wallet
        enterMarket(ctokenAddrArr);
        for (uint i = 0; i < ctokenAddrArr.length; i++) {
            address erc20 = ctokenAddrArr[i];
            ERC20Interface tknContract = ERC20Interface(erc20);
            uint tokenBal = tknContract.balanceOf(msg.sender);
            tokenBal = toConvert < 10**18 ? wmul(tokenBal, toConvert) : tokenBal;
            if (tokenBal > 0) {
                require(tknContract.transferFrom(msg.sender, address(this), tokenBal), "Allowance?");
            }
            tokenBalArr[i] = tokenBal;
        }

        emit LogCTokensImport(
            msg.sender,
            toConvert,
            ctokenAddrArr,
            tokenBalArr
        );
    }
}


contract InstaTokenImport is ImportResolver {
    function() external payable {}
}