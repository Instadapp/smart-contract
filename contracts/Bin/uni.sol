pragma solidity ^0.5.7;

interface UniswapExchange {
    function ethToTokenSwapInput(uint minTokens, uint deadline) external payable returns (uint tokenBought);
    function tokenToEthSwapInput(uint tokenSold, uint minEth, uint deadline) external returns (uint ethBought);
}

interface TokenInterface {
    function transfer(address, uint) external returns (bool);
    function approve(address, uint) external;
    function transferFrom(address, address, uint) external returns (bool);
}


contract Swap {
    
    address public daiAddr = 0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359;
    address public daiExchange = 0x09cabEC1eAd1c0Ba254B09efb3EE13841712bE14;
    
    function ethToDai() public payable {
        uint destAmt = UniswapExchange(daiExchange).ethToTokenSwapInput.value(msg.value)(1, block.timestamp + 1);
        require(TokenInterface(daiAddr).transfer(msg.sender, destAmt));
    }
    
    function daiToEth(uint daiAmt) public {
        require(TokenInterface(daiAddr).transferFrom(msg.sender, address(this), daiAmt));
        TokenInterface(daiAddr).approve(daiExchange, daiAmt);
        uint destAmt = UniswapExchange(daiExchange).tokenToEthSwapInput(daiAmt, 1, block.timestamp + 1);
        msg.sender.transfer(destAmt);
    }
    
    function() external payable {}
    
}