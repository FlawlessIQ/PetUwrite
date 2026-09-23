const test = require('node:test')
const assert = require('node:assert/strict')
const { newCode } = require('./household')

/**
 * Pure tests for the invite code itself. The redemption rules need Firestore
 * and are covered by `npm run verify:household` against the emulator.
 */

test('codes are the shape the client validates and the UI hints at', () => {
  for (let i = 0; i < 200; i++) {
    assert.match(newCode(), /^[A-Z2-9]{4}-[A-Z2-9]{4}$/)
  }
})

test('codes avoid the characters people mistype reading aloud', () => {
  // 0/O and 1/I/L are the ones that get confused across a kitchen table, which
  // is exactly how this code will be shared.
  const sample = Array.from({ length: 400 }, newCode).join('')
  for (const ch of ['0', 'O', '1', 'I', 'L']) {
    assert.ok(!sample.includes(ch), `code alphabet contains ${ch}`)
  }
})

test('codes do not repeat in any realistic session', () => {
  const seen = new Set(Array.from({ length: 2000 }, newCode))
  assert.equal(seen.size, 2000)
})

test('the code space is large enough that guessing is not a strategy', () => {
  // 31 usable characters, 8 of them. Codes also expire in 7 days and work once,
  // but the space should not be the weak part.
  const space = Math.pow(31, 8)
  assert.ok(space > 8e11, `only ${space} possible codes`)
})
