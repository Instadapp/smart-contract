const { BN } = web3.utils

const decimals18 = new BN(10).pow(new BN(18))
const bigZero = new BN(0)
const addressZero = `0x${'0'.repeat(40)}`
const bytes32Zero = '0x' + '00'.repeat(32)
const gasPrice = new BN(5e9)

const assertRevert = async promise => {
  try {
    await promise
    assert.fail('Expected revert not received')
  } catch (error) {
    const revertFound = error.message.search('revert') >= 0
    assert(revertFound, `Expected "revert", got ${error} instead`)
  }
}

const assertJump = async promise => {
  try {
    await promise
    assert.fail('Expected invalid opcode not received')
  } catch (error) {
    const invalidOpcodeReceived = error.message.search('invalid opcode') >= 0
    assert(
      invalidOpcodeReceived,
      `Expected "invalid opcode", got ${error} instead`
    )
  }
}

const assertThrow = async promise => {
  try {
    await promise
  } catch (error) {
    // TODO: Check jump destination to destinguish between a throw
    //       and an actual invalid jump.
    const invalidOpcode = error.message.search('invalid opcode') >= 0
    // TODO: When we contract A calls contract B, and B throws, instead
    //       of an 'invalid jump', we get an 'out of gas' error. How do
    //       we distinguish this from an actual out of gas event? (The
    //       testrpc log actually show an 'invalid jump' event.)
    const outOfGas = error.message.search('out of gas') >= 0
    const revert = error.message.search('revert') >= 0
    const exception =
      error.message.search(
        'VM Exception while processing transaction: revert'
      ) >= 0
    assert(
      invalidOpcode || exception || outOfGas || revert,
      "Expected throw, got '" + error + "' instead"
    )
    return
  }

  assert.fail('Expected throw not received')
}

const waitForEvent = (contract, event, optTimeout) =>
  new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      clearTimeout(timeout)
      return reject(new Error('Timeout waiting for contractEvent'))
    }, optTimeout || 5000)

    const eventEmitter = contract.contract.events[event]()
    eventEmitter
      .on('data', data => {
        eventEmitter.unsubscribe()
        clearTimeout(timeout)
        resolve(data)
      })
      .on('changed', data => {
        clearTimeout()
        eventEmitter.unsubscribe()
        resolve(data)
      })
      .on('error', err => {
        eventEmitter.unsubscribe()
        reject(err)
      })
  })

const areInRange = (num1, num2, range) => {
  const bigNum1 = new BN(num1.toString())
  const bigNum2 = new BN(num2.toString())
  const bigRange = new BN(range.toString())

  if (bigNum1.equals(bigNum2)) {
    return true
  }

  const larger = bigNum1.gt(bigNum2) ? bigNum1 : bigNum2
  const smaller = bigNum1.lt(bigNum2) ? bigNum1 : bigNum2

  return larger.sub(smaller).lt(bigRange)
}

const getNowInSeconds = () => new BN(Date.now()).div(1000).floor(0)

const trimBytes32Array = bytes32Array =>
  bytes32Array.filter(bytes32 => bytes32 != bytes32Zero)

const getEtherBalance = address => {
  return new Promise((resolve, reject) => {
    web3.eth.getBalance(address, (err, res) => {
      if (err) reject(err)

      resolve(res)
    })
  })
}

const getTxInfo = txHash => {
  if (typeof txHash === 'object') {
    return txHash.receipt
  }

  return new Promise((resolve, reject) => {
    web3.eth.getTransactionReceipt(txHash, (err, res) => {
      if (err) {
        reject(err)
      }

      resolve(res)
    })
  })
}

const sendTransaction = args => {
  return new Promise(function(resolve, reject) {
    web3.eth.sendTransaction(args, (err, res) => {
      if (err) {
        reject(err)
      } else {
        resolve(res)
      }
    })
  })
}

module.exports = {
  decimals18,
  bigZero,
  addressZero,
  bytes32Zero,
  gasPrice,
  assertRevert,
  assertJump,
  assertThrow,
  waitForEvent,
  areInRange,
  getNowInSeconds,
  trimBytes32Array,
  getEtherBalance,
  getTxInfo,
  sendTransaction
}
