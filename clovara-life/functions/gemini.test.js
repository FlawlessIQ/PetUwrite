const test = require('node:test')
const assert = require('node:assert/strict')
const { toCandidates, SYSTEM } = require('./gemini')

/**
 * The model is not tested here — it is a third party and it changes. What is
 * tested is the gate between it and a pet's record, which is ours.
 */

test('drops a candidate whose quoted words are not in what the owner wrote', () => {
  // The load-bearing check. If the model quotes something that was never said,
  // it invented it, and an invented candidate confirmed by an owner is
  // indistinguishable from a real record forever after.
  const out = toCandidates(
    [{ kind: 'weight', label: '30 lb', sourceText: 'he weighs 30 lb', weightLb: 30 }],
    'Scout is a lovely dog',
  )
  assert.equal(out.length, 0)
})

test('keeps one it can substantiate', () => {
  const out = toCandidates(
    [{ kind: 'weight', label: 'About 68 lb', sourceText: '68 lbs', weightLb: 68 }],
    'He is about 68 lbs and full of beans',
  )
  assert.equal(out.length, 1)
  assert.deepEqual(out[0].value, { weightLb: 68 })
})

test('matches the quote case-insensitively, since models re-case things', () => {
  const out = toCandidates(
    [{ kind: 'condition', label: 'Neutered', sourceText: 'Neutered', neutered: true }],
    'he is neutered',
  )
  assert.equal(out.length, 1)
})

test('refuses a nonsense weight', () => {
  for (const w of [0, -5, 900, NaN]) {
    const out = toCandidates(
      [{ kind: 'weight', label: 'x', sourceText: 'weighs', weightLb: w }],
      'he weighs something',
    )
    assert.equal(out.length, 0, `accepted ${w}`)
  }
})

test('drops a candidate with no usable value', () => {
  const out = toCandidates(
    [{ kind: 'visit', label: 'Saw the vet', sourceText: 'saw the vet' }],
    'we saw the vet last week',
  )
  assert.equal(out.length, 0)
})

test('produces candidates, never stored fields (invariant 8)', () => {
  const out = toCandidates(
    [{ kind: 'weight', label: '68 lb', sourceText: '68 lbs', weightLb: 68 }],
    'he is 68 lbs',
  )
  for (const c of out) {
    assert.ok(!('provenance' in c), 'a candidate carried provenance')
    assert.ok(!('confirmedAt' in c), 'a candidate carried a confirmation time')
    assert.ok('sourceText' in c)
  }
})

test('survives rubbish from the model without throwing', () => {
  for (const junk of [null, undefined, 'nope', [null], [{}], [{ kind: 'weight' }]]) {
    assert.doesNotThrow(() => toCandidates(junk, 'anything'))
  }
})

test('truncates a label the model let run away', () => {
  const out = toCandidates(
    [{ kind: 'weight', label: 'x'.repeat(500), sourceText: '68 lbs', weightLb: 68 }],
    'he is 68 lbs',
  )
  assert.ok(out[0].label.length <= 120)
})

test('the prompt puts negation first, because it is the damaging failure', () => {
  const firstRule = SYSTEM.slice(SYSTEM.indexOf('1.'), SYSTEM.indexOf('2.'))
  assert.match(firstRule, /negation is not a fact/i)
  assert.match(firstRule, /no history of seizures/i)
  assert.match(SYSTEM, /never diagnose/i)
  assert.match(SYSTEM, /when unsure, return nothing/i)
})
