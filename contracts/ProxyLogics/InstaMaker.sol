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
    
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "Assertion Failed");
        uint256 c = a / b;
        return c;
    }

}


contract IERC20 {
    function balanceOf(address who) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}


contract MakerCDP {
    function open() external returns (bytes32 cup);
    function join(uint wad) external; // Join PETH
    function exit(uint wad) external; // Exit PETH
    function give(bytes32 cup, address guy) external;
    function lock(bytes32 cup, uint wad) external;
    function free(bytes32 cup, uint wad) external;
    function draw(bytes32 cup, uint wad) external;
    function wipe(bytes32 cup, uint wad) external;
    function per() external view returns (uint ray);
    function lad(bytes32 cup) external view returns (address);
}


contract PriceInterface {
    function peek() external view returns (bytes32, bool);
}


contract WETHFace {
    function deposit() external payable;
    function withdraw(uint wad) external;
}


contract Helpers {

    using SafeMath for uint;
    using SafeMath for uint256;

    function getETHRate() public view returns (uint) {
        PriceInterface ethRate = PriceInterface(getAddress("ethfeed"));
        bytes32 ethrate;
        (ethrate, ) = ethRate.peek();
        return uint(ethrate);
    }

    function getCDP(address borrower) public view returns (uint, bytes32) {
        return (uint(cdps[borrower]), cdps[borrower]);
    }

    function approveERC20() public {
        IERC20 wethTkn = IERC20(getAddress("weth"));
        wethTkn.approve(cdpAddr, 2**256 - 1);
        IERC20 pethTkn = IERC20(getAddress("peth"));
        pethTkn.approve(cdpAddr, 2**256 - 1);
        IERC20 mkrTkn = IERC20(getAddress("mkr"));
        mkrTkn.approve(cdpAddr, 2**256 - 1);
        IERC20 daiTkn = IERC20(getAddress("dai"));
        daiTkn.approve(cdpAddr, 2**256 - 1);
    }


}


contract IssueLoan is Helpers {

    event LockedETH(address borrower, uint lockETH, uint lockPETH, address lockedBy);
    event LoanedDAI(address borrower, uint loanDAI, address payTo);
    event NewCDP(address borrower, bytes32 cdpBytes);

    function pethPEReth(uint ethNum) public view returns (uint rPETH) {
        MakerCDP loanMaster = MakerCDP(cdpAddr);
        rPETH = (ethNum.mul(10 ** 27)).div(loanMaster.per());
    }

    function borrow(uint daiDraw, address beneficiary) public payable {
        if (msg.value > 0) {lockETH(msg.sender);}
        if (daiDraw > 0) {drawDAI(daiDraw, beneficiary);}
    }

    function lockETH(address borrower) public payable {
        MakerCDP loanMaster = MakerCDP(cdpAddr);
        if (cdps[borrower] == blankCDP) {
            require(msg.sender == borrower, "Creating CDP for others is not permitted at the moment.");
            cdps[msg.sender] = loanMaster.open();
            emit NewCDP(msg.sender, cdps[msg.sender]);
        }
        WETHFace wethTkn = WETHFace(getAddress("weth"));
        wethTkn.deposit.value(msg.value)(); // ETH to WETH
        uint pethToLock = pethPEReth(msg.value);
        loanMaster.join(pethToLock); // WETH to PETH
        loanMaster.lock(cdps[borrower], pethToLock); // PETH to CDP
        emit LockedETH(
            borrower, msg.value, pethToLock, msg.sender
        );
    }

    function drawDAI(uint daiDraw, address beneficiary) public {
        require(!freezed, "Operation Disabled");
        MakerCDP loanMaster = MakerCDP(cdpAddr);
        loanMaster.draw(cdps[msg.sender], daiDraw);
        IERC20 daiTkn = IERC20(getAddress("dai"));
        address payTo = msg.sender;
        if (payTo != address(0)) {
            payTo = beneficiary;
        }
        daiTkn.transfer(payTo, daiDraw);
        emit LoanedDAI(msg.sender, daiDraw, payTo);
    }

}


contract RepayLoan is IssueLoan {

    event WipedDAI(address borrower, uint daiWipe, uint mkrCharged, address wipedBy);
    event UnlockedETH(address borrower, uint ethFree);

    function repay(uint daiWipe, uint ethFree) public payable {
        if (daiWipe > 0) {wipeDAI(daiWipe, msg.sender);}
        if (ethFree > 0) {unlockETH(ethFree);}
    }

    function wipeDAI(uint daiWipe, address borrower) public payable {
        address dai = getAddress("dai");
        address mkr = getAddress("mkr");
        address eth = getAddress("eth");

        IERC20 daiTkn = IERC20(dai);
        IERC20 mkrTkn = IERC20(mkr);

        uint contractMKR = mkrTkn.balanceOf(address(this)); // contract MKR balance before wiping
        daiTkn.transferFrom(msg.sender, address(this), daiWipe); // get DAI to pay the debt
        MakerCDP loanMaster = MakerCDP(cdpAddr);
        loanMaster.wipe(cdps[borrower], daiWipe); // wipe DAI
        uint mkrCharged = contractMKR - mkrTkn.balanceOf(address(this)); // MKR fee = before wiping bal - after wiping bal

        // claiming paid MKR back
        if (msg.value > 0) { // Interacting with Kyber to swap ETH with MKR
            swapETHMKR(
                eth, mkr, mkrCharged, msg.value
            );
        } else { // take MKR directly from address
            mkrTkn.transferFrom(msg.sender, address(this), mkrCharged); // user paying MKR fees
        }

        emit WipedDAI(
            borrower, daiWipe, mkrCharged, msg.sender
        );
    }

    function unlockETH(uint ethFree) public {
        require(!freezed, "Operation Disabled");
        uint pethToUnlock = pethPEReth(ethFree);
        MakerCDP loanMaster = MakerCDP(cdpAddr);
        loanMaster.free(cdps[msg.sender], pethToUnlock); // CDP to PETH
        loanMaster.exit(pethToUnlock); // PETH to WETH
        WETHFace wethTkn = WETHFace(getAddress("weth"));
        wethTkn.withdraw(ethFree); // WETH to ETH
        msg.sender.transfer(ethFree);
        emit UnlockedETH(msg.sender, ethFree);
    }

    function swapETHMKR(
        address eth,
        address mkr,
        uint mkrCharged,
        uint ethQty
    ) internal 
    {
        InstaKyber instak = InstaKyber(getAddress("InstaKyber"));
        uint minRate;
        (, minRate) = instak.getExpectedPrice(eth, mkr, ethQty);
        uint mkrBought = instak.executeTrade.value(ethQty)(
            eth, mkr, ethQty, minRate, mkrCharged
        );
        require(mkrCharged == mkrBought, "ETH not sufficient to cover the MKR fees.");
        if (address(this).balance > 0) {
            msg.sender.transfer(address(this).balance);
        }
    }



}

contract InstaMaker is BorrowTasks {

    uint public version;
    
    /**
     * @dev setting up variables on deployment
     * 1...2...3 versioning in each subsequent deployments
     */
    constructor(uint _version) public {
        version = _version;
    }

}