pragma solidity ^0.5.7;

interface ERC20Interface {
    function allowance(address, address) external view returns (uint);
    function balanceOf(address) external view returns (uint);
    function approve(address, uint) external;
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
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


contract ImportResolver is DSMath {
    event LogTokensImport(address owner, uint percentage, address[] tokenAddr, uint[] tokenBalArr);

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
}


contract InstaTokenImport is ImportResolver {
    function() external payable {}
}