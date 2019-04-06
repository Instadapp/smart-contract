pragma solidity ^0.5.2;


interface TubInterface {
    function gem() external view returns (TokenInterface);
}


interface TokenInterface {
    function allowance(address, address) external view returns (uint);
    function balanceOf(address) external view returns (uint);
    function transfer(address, uint) external returns (bool);
    function approve(address, uint) external;
    function withdraw(uint) external;
}


contract FreeProxy {

    function getSaiTubAddress() public pure returns (address sai) {
        sai = 0x448a5065aeBB8E423F0896E6c5D525C040f59af3;
    }

    function getAddressWETH() public pure returns (address weth) {
        weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    }

    function freeWETH(uint wamt) public {
        TubInterface tub = TubInterface(getSaiTubAddress());
        TokenInterface weth = tub.gem();

        uint freeJam = wamt;
        if (freeJam == 0) {
            freeJam = weth.balanceOf(address(this));
        }

        weth.withdraw(freeJam);
        msg.sender.transfer(freeJam);
    }

    function withdrawWETH() public {
        TubInterface tub = TubInterface(getSaiTubAddress());
        TokenInterface weth = tub.gem();
        uint freeJam = weth.balanceOf(address(this));
        weth.transfer(msg.sender, freeJam);
    }

    function getWETHBal() public view returns (uint freeJam) {
        TubInterface tub = TubInterface(getSaiTubAddress());
        TokenInterface weth = tub.gem();
        freeJam = weth.balanceOf(address(this));
    }

    function getSaiWETH() public view returns (address) {
        TubInterface tub = TubInterface(getSaiTubAddress());
        return address(tub.gem());
    }

    function setAllowance(TokenInterface token_, address spender_) private {
        if (token_.allowance(address(this), spender_) != uint(-1)) {
            token_.approve(spender_, uint(-1));
        }
    }

}