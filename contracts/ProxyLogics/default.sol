pragma solidity ^0.5.0;

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
}

interface ICDP {
    function give(bytes32 cup, address guy) external;
}


contract ProxyTest {
    event LogTransferETH(address dest, uint amount);
    event LogTransferERC20(address token, address dest, uint amount);
    event LogTransferCDP(address dest, uint num);

    function transferETH(address dest, uint amount) public payable {
        dest.transfer(amount);

        emit LogTransferETH(
            dest, 
            amount
        );
    }

    function transferERC20(address tokenAddr, address dest, address amount) public {
        IERC20 tkn = IERC20(tokenAddr);
        tkn.transfer(dest, amount);
        emit LogTransferERC20(tokenAddr, dest, amount);
    }

    function transferCDP(address tub, address dest, uint num) public {
        ICDP loanMaster = ICDP(tub);
        loanMaster.give(bytes32(num), dest);
        emit LogTransferCDP(dest, num);
    }
}