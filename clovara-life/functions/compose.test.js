const test = require('node:test')
const assert = require('node:assert/strict')
const { composeReply, COMPANION_MODEL_ENABLED, SYSTEM, SCHEMA } = require('./compose')

test('it ships OFF, pending the privacy decision', async () => {
  assert.equal(COMPANION_MODEL_ENABLED, false)
  await assert.rejects(
    () => composeReply({ utterance: 'hello', facts: [], petName: 'Scout' }, 'key'),
    /switched off pending a decision/,
  )
})

test('the schema cannot express an uncited sentence', () => {
  const item = SCHEMA.properties.sentences.items
  assert.ok(item.required.includes('citesFactIds'))
  assert.ok(item.required.includes('text'))
})

test('the route enum cannot express anything we do not handle', () => {
  assert.deepEqual(SCHEMA.properties.routeTo.enum, ['vet-soon', 'vet-now', 'none'])
})

test('the prompt forbids the four things verification also drops', () => {
  // Belt and braces on purpose: the prompt asks, the schema constrains, and
  // verification enforces. Only the third is load-bearing.
  assert.match(SYSTEM, /never/i)
  assert.match(SYSTEM, /not "probably", not "could be"/i)
  assert.match(SYSTEM, /dose, a drug, or a home treatment/i)
  assert.match(SYSTEM, /promise a longer life/i)
  assert.match(SYSTEM, /invent a fact id/i)
})

test('the prompt tells it to prefer saying less', () => {
  assert.match(SYSTEM, /prefer saying less/i)
  assert.match(SYSTEM, /no credit for length/i)
})

test('the prompt tells it to refuse identification rather than hedge', () => {
  assert.match(SYSTEM, /if asked what it is, say you cannot tell them/i)
})
