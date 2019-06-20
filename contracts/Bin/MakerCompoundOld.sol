pragma solidity ^0.5.7;

interface RegistryInterface {
    function proxies(address) external view returns (address);
}

interface UserWalletInterface {
    function owner() external view returns (address);
}

interface CTokenInterface {
    function mint(uint mintAmount) external returns (uint); // For ERC20
    function redeem(uint redeemTokens) external returns (uint);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
    function exchangeRateCurrent() external returns (uint);
    function allowance(address, address) external view returns (uint);
    function approve(address, uint) external;
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
}

interface ERC20Interface {
    function allowance(address, address) external view returns (uint);
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

    function wdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, WAD), y / 2) / y;
    }

}


contract Helper is DSMath {

    address public daiAddr = 0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359;
    address public cdaiAddr = 0xF5DCe57282A584D2746FaF1593d3121Fcac444dC;
    address public registryAddr = 0x498b3BfaBE9F73db90D252bCD4Fa9548Cd0Fd981;
    mapping (address => uint) public deposited; // amount of CToken deposited
    mapping (address => bool) public isAdmin;

    /**
     * @dev setting allowance to compound for the "user proxy" if required
     */
    function setApproval(address erc20, uint srcAmt, address to) internal {
        ERC20Interface erc20Contract = ERC20Interface(erc20);
        uint tokenAllowance = erc20Contract.allowance(address(this), to);
        if (srcAmt > tokenAllowance) {
            erc20Contract.approve(to, 2**255);
        }
    }

    modifier isUserWallet {
        address userAdd = UserWalletInterface(msg.sender).owner();
        address walletAdd = RegistryInterface(registryAddr).proxies(userAdd);
        require(walletAdd != address(0), "Not-User-Wallet");
        require(walletAdd == msg.sender, "Not-Wallet-Owner");
        _;
    }

}


contract CTokens is Helper {

    struct CTokenData {
        address cTokenAdd;
        uint factor;
    }

    CTokenData[] public cTokenAddr;

    uint public cArrLength = 0;

    function addCToken(address cToken, uint factor) public {
        require(isAdmin[msg.sender], "Address not an admin");
        CTokenData memory setCToken = CTokenData(cToken, factor);
        cTokenAddr.push(setCToken);
        cArrLength++;
    }

}


contract Bridge is CTokens {

    /**
     * @dev Deposit DAI for liquidity
     */
    function depositDAI(uint amt) public {
        ERC20Interface(daiAddr).transferFrom(msg.sender, address(this), amt);
        CTokenInterface cToken = CTokenInterface(cdaiAddr);
        assert(cToken.mint(amt) == 0);
        uint cDaiAmt = wdiv(amt, cToken.exchangeRateCurrent());
        deposited[msg.sender] += cDaiAmt;
    }

    /**
     * @dev Withdraw DAI from liquidity
     */
    function withdrawDAI(uint amt) public {
        require(deposited[msg.sender] != 0, "Nothing to Withdraw");
        CTokenInterface cToken = CTokenInterface(cdaiAddr);
        uint withdrawAmt = wdiv(amt, cToken.exchangeRateCurrent());
        uint daiAmt = amt;
        if (withdrawAmt > deposited[msg.sender]) {
            withdrawAmt = deposited[msg.sender];
            daiAmt = wmul(withdrawAmt, cToken.exchangeRateCurrent());
        }
        require(cToken.redeem(withdrawAmt) == 0, "something went wrong");
        ERC20Interface(daiAddr).transfer(msg.sender, daiAmt);
        deposited[msg.sender] -= withdrawAmt;
    }

    /**
     * @dev Deposit CDAI for liquidity
     */
    function depositCDAI(uint amt) public {
        CTokenInterface cToken = CTokenInterface(cdaiAddr);
        require(cToken.transferFrom(msg.sender, address(this), amt) == true, "Nothing to deposit");
        deposited[msg.sender] += amt;
    }

    /**
     * @dev Withdraw CDAI from liquidity
     */
    function withdrawCDAI(uint amt) public {
        require(deposited[msg.sender] != 0, "Nothing to Withdraw");
        CTokenInterface cToken = CTokenInterface(cdaiAddr);
        uint withdrawAmt = amt;
        if (withdrawAmt > deposited[msg.sender]) {
            withdrawAmt = deposited[msg.sender];
        }
        cToken.transfer(msg.sender, withdrawAmt);
        deposited[msg.sender] -= withdrawAmt;
    }

    /**
     * @dev Transfer DAI to only to user wallet
     */
    function transferDAI(uint amt) public isUserWallet {
        CTokenInterface cToken = CTokenInterface(cdaiAddr);
        require(cToken.redeemUnderlying(amt) == 0, "something went wrong");
        ERC20Interface(daiAddr).transfer(msg.sender, amt);
    }

    /**
     * @dev Take DAI back from user wallet
     */
    function transferBackDAI(uint amt) public isUserWallet {
        ERC20Interface tokenContract = ERC20Interface(daiAddr);
        tokenContract.transferFrom(msg.sender, address(this), amt);
        CTokenInterface cToken = CTokenInterface(cdaiAddr);
        assert(cToken.mint(amt) == 0);
    }

}


contract MakerCompBridge is Bridge {

    uint public version;

    /**
     * @dev setting up variables on deployment
     * 1...2...3 versioning in each subsequent deployments
     */
    constructor(uint _version) public {
        isAdmin[0x7284a8451d9a0e7Dc62B3a71C0593eA2eC5c5638] = true;
        isAdmin[0xa7615CD307F323172331865181DC8b80a2834324] = true;
        addCToken(0x6C8c6b02E7b2BE14d4fA6022Dfd6d75921D90E4E, 600000000000000000);
        addCToken(0xF5DCe57282A584D2746FaF1593d3121Fcac444dC, 750000000000000000);
        addCToken(0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5, 750000000000000000);
        addCToken(0x158079Ee67Fce2f58472A96584A73C7Ab9AC95c1, 500000000000000000);
        addCToken(0x39AA39c021dfbaE8faC545936693aC917d5E7563, 750000000000000000);
        addCToken(0xB3319f5D18Bc0D84dD1b4825Dcde5d5f7266d407, 600000000000000000);
        setApproval(daiAddr, 10**30, cdaiAddr);
        setApproval(cdaiAddr, 10**30, cdaiAddr);
        version = _version;
    }

    function() external payable {}

}