const test = require('node:test')
const assert = require('node:assert/strict')
const { planSends, sentKey, MAX_PER_DAY } = require('./moments-runner')

const NOW = new Date('2026-09-30T12:00:00Z')
const f = (v) => ({ value: v, provenance: 'owner_declared', updatedAt: NOW.toISOString(), updatedBy: 'u1' })
const ago = (days) => new Date(NOW.getTime() - days * 86400000).toISOString()
const storedPet = (id, over = {}) => ({
  id, householdId: 'h1', createdAt: ago(1), createdBy: 'u1',
  name: f('Bruno'), species: f('dog'), breedId: f('labrador-retriever'), sex: f('male'), conditionIds: f([]),
  // Home since yesterday morning, ten weeks old: the first night and a DHP window.
  birthDate: f(ago(71).slice(0, 10)), knownSince: f(new Date(NOW.getTime() - 20 * 3600000).toISOString()),
  ...over,
})
const person = (over = {}) => ({
  uid: 'u1', email: 'owner@example.test',
  prefs: { moments: true, sent: {}, unsubscribeToken: 'tok' },
  pets: [storedPet('p1')], ...over,
})
const plan = (recipients) => planSends({ now: NOW, recipients, preferencesUrl: 'https://example.test/emailPreferences' })

test('an opted-in owner gets what is due, from the app\'s engine', () => {
  const s = plan([person()])
  assert.ok(s.length >= 1)
  assert.ok(s.some((x) => x.key === sentKey('p1', 'first-nights')))
  assert.equal(s[0].data.petName, 'Bruno')
  assert.match(s[0].data.preferencesUrl, /\?t=tok$/)
  assert.equal(s[0].headers['List-Unsubscribe-Post'], 'List-Unsubscribe=One-Click')
})

test('nobody who has not opted in, and nobody without an email', () => {
  assert.deepEqual(plan([person({ prefs: { moments: false, sent: {} } })]), [])
  assert.deepEqual(plan([person({ prefs: undefined })]), [])
  assert.deepEqual(plan([person({ email: null })]), [])
})

test('a moment goes once', () => {
  const first = plan([person()])
  const sent = Object.fromEntries(first.map((x) => [x.key, NOW.toISOString()]))
  assert.deepEqual(plan([person({ prefs: { moments: true, sent, unsubscribeToken: 'tok' } })]), [])
})

test(`no more than ${MAX_PER_DAY} a day for one person, however many pets`, () => {
  const pets = ['a', 'b', 'c', 'd'].map((id) => storedPet(id))
  assert.equal(plan([person({ pets })]).length, MAX_PER_DAY)
})

test('nothing about a pet who has died', () => {
  assert.deepEqual(plan([person({ pets: [storedPet('p1', { diedOn: f(ago(1).slice(0, 10)) })] })]), [])
})
