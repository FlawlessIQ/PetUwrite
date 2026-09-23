const test = require('node:test')
const assert = require('node:assert/strict')
const { newToken, cardFromPet, DEFAULT_TTL_DAYS, MAX_TTL_DAYS } = require('./sitter')

/**
 * Pure tests for the token and for what a sitter card exposes. The expiry and
 * revocation rules need Firestore and are covered against the emulator by
 * `npm run verify:sitter`.
 */

test('the token is long and unguessable, not a human-readable code', () => {
  // The invite code is short because somebody reads it across a kitchen table.
  // This one is pasted, so it can be 32 bytes instead.
  const t = newToken()
  assert.match(t, /^[A-Za-z0-9_-]+$/)
  assert.ok(t.length >= 40, `token only ${t.length} chars`)
})

test('tokens do not repeat', () => {
  const seen = new Set(Array.from({ length: 5000 }, newToken))
  assert.equal(seen.size, 5000)
})

test('the card carries what a sitter needs', () => {
  const card = cardFromPet({
    name: { value: 'Scout' },
    species: { value: 'dog' },
    breedId: { value: 'labrador-retriever' },
    careNotes: {
      value: {
        feeding: 'Two scoops, morning and evening.',
        meds: 'Half a tablet with breakfast.',
        quirks: 'Hates the hoover.',
        vetName: 'Riverside Vets',
        vetPhone: '01234 567890',
        emergencyName: 'Jo',
        emergencyPhone: '07700 900000',
      },
    },
  })
  assert.equal(card.name, 'Scout')
  assert.equal(card.medication, 'Half a tablet with breakfast.')
  assert.equal(card.vetPhone, '01234 567890')
  assert.equal(card.emergencyName, 'Jo')
})

test('the card carries NOTHING a fridge note would not', () => {
  // A link that leaks should leak a fridge note, not a record. No projection,
  // no conditions as medical history, no owner identity, no household id, no
  // membership or billing.
  const card = cardFromPet({
    name: { value: 'Scout' },
    species: { value: 'dog' },
    weightLb: { value: 68 },
    conditionIds: { value: ['hip-dysplasia'] },
    ownerEmail: { value: 'someone@example.com' },
    entitlement: { value: { status: 'active' } },
    householdId: { value: 'hh_123' },
    lastReviewedRange: { value: { low: 10, high: 13 } },
  })
  const keys = Object.keys(card)
  for (const leaked of [
    'weightLb',
    'conditionIds',
    'ownerEmail',
    'entitlement',
    'householdId',
    'lastReviewedRange',
  ]) {
    assert.ok(!keys.includes(leaked), `sitter card exposes ${leaked}`)
  }
  const blob = JSON.stringify(card)
  assert.ok(!blob.includes('someone@example.com'), 'owner email reached the card')
  assert.ok(!blob.includes('hip-dysplasia'), 'a diagnosis reached the card')
  assert.ok(!blob.includes('hh_123'), 'the household id reached the card')
})

test('a pet with no care notes still produces a card rather than throwing', () => {
  const card = cardFromPet({ name: { value: 'Pip' }, species: { value: 'cat' } })
  assert.equal(card.name, 'Pip')
  assert.equal(card.feeding, null)
  assert.equal(card.vetPhone, null)
})

test('the default expiry is short and the maximum is bounded', () => {
  assert.equal(DEFAULT_TTL_DAYS, 7)
  assert.ok(MAX_TTL_DAYS <= 30, 'a sitter link should not outlive the sit by months')
})
