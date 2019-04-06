module.exports = {
  port: 9545,
  testrpcOptions:
    '-p 9545 -m "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat"',
  testCommand: 'truffle test --network coverage',
  norpc: true,
  copyPackages: ['openzeppelin-solidity'],
  skipFiles: ['Bin/DEX.sol', 'Bin/Kyber.sol', 'Bin/Uniswap.sol', 'Bin/FreeProxy.sol', 'Reference/Auth.sol','Migrations.sol']
}
