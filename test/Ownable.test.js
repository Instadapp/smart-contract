const { assertRevert } = require('./helpers/general')

const Ownable = artifacts.require('Ownable')

contract('Ownable', accounts => {
  let ownable

  beforeEach(async () => {
    ownable = await Ownable.new()
  })

  it('should have an owner', async () => {
    const owner = await ownable.owner()
    assert.isTrue(owner !== 0)
  })

  it('changes owner after transfer', async () => {
    const other = accounts[1]
    await ownable.transferOwnership(other)
    const owner = await ownable.owner()

    assert.isTrue(owner === other)
  })

  it('should prevent non-owners from transfering', async () => {
    const other = accounts[2]
    const owner = await ownable.owner.call()
    assert.isTrue(owner !== other)
    await assertRevert(ownable.transferOwnership(other, { from: other }))
  })
})
