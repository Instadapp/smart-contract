require('dotenv').config()
const HDWalletProvider = require('truffle-hdwallet-provider')

const rinkebyWallet =
  'candy maple cake sugar pudding cream honey rich smooth crumble sweet treat'
const rinkebyProvider = new HDWalletProvider(
  rinkebyWallet,
  'https://rinkeby.infura.io/'
)

const ropstenWallet =
  'candy maple cake sugar pudding cream honey rich smooth crumble sweet treat'
const ropstenProvider = new HDWalletProvider(
  ropstenWallet,
  'https://ropsten.infura.io/'
)

module.exports = {
  migrations_directory: './migrations',
  networks: {
    test: {
      host: 'localhost',
      port: 9545,
      network_id: '*',
      gas: 6.5e6,
      gasPrice: 5e9,
      websockets: true
    },
    ropsten: {
      network_id: 3,
      gas: 6.5e6,
      gasPrice: 5e9,
      provider: () => ropstenProvider
    },
    rinkeby: {
      network_id: 4,
      gas: 6.5e6,
      gasPrice: 5e9,
      provider: () => rinkebyProvider
    }
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 500
    }
  },
  mocha: {
    reporter: 'mocha-multi-reporters',
    useColors: true,
    enableTimeouts: false,
    reporterOptions: {
      configFile: './mocha-smart-contracts-config.json'
    }
  }
}
