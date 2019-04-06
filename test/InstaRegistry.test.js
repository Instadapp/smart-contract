const truffleAssert = require('truffle-assertions')
const { assertRevert } = require('./helpers/general')
const InstaRegistry = artifacts.require('InstaRegistry')

contract('InstaRegistry', accounts => {
  let instaRegistry
  const user = accounts[0]

  beforeEach(async () => {
    instaRegistry = await InstaRegistry.new({
      from: user
    })
  })

  it('user should be owner and admin', async () => {
    const admin = await instaRegistry.getAddress('admin', {
      from: user
    })

    assert.equal(admin, user, 'user is admin')
  })

  it('only admin or owner should be able to set address', async () => {
    const result = await instaRegistry.setAddress('admin', accounts[2], {
      from: user
    })

    expect(result.receipt.status).to.equal(true)
    truffleAssert.prettyPrintEmittedEvents(result)
    truffleAssert.eventEmitted(
      result,
      'LogSetAddress',
      event => {
        return event.name === 'admin' && event.addr === accounts[2]
      },
      'LogSetAddress should be emitted with correct parameters'
    )
  })

  it('revert when non-admin tries to set address', async () => {
    await assertRevert(
      instaRegistry.setAddress('admin', accounts[2], {
        from: user
      })
    )
  })
})
