const ownableFactory = artifacts.require('Ownable.sol')

module.exports = async deployer => {
  await deployer.deploy(ownableFactory)
}
