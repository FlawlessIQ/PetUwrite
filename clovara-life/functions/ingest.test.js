const test = require('node:test')
const assert = require('node:assert/strict')
const { validateBatch, makeLimiter, MAX_EVENTS } = require('./ingest')

const NOW = new Date('2026-09-30T12:00:00Z')
const ev = (over = {}) => ({ name: 'first_visit', props: { utm_source: 'rescue' }, at: '2026-09-30T11:59:00Z', visitorId: 'visitor-abc-123', sessionId: 'session-xyz-789', build: 'b1', ...over })

test('keeps a well-formed event, anonymous and sanitised', () => {
  const { events, refused } = validateBatch({ events: [ev()] }, NOW)
  assert.equal(refused, 0)
  assert.deepEqual(events[0], { name: 'first_visit', props: { utm_source: 'rescue' }, at: '2026-09-30T11:59:00.000Z', visitorId: 'visitor-abc-123', sessionId: 'session-xyz-789', build: 'b1', uid: null, anon: true })
})

test('refuses names not on the list, bad ids, and times from the future or the distant past', () => {
  const { events, refused } = validateBatch({ events: [
    ev({ name: 'drop_table' }), ev({ visitorId: 'x' }), ev({ sessionId: '<script>' }),
    ev({ at: '2026-10-05T00:00:00Z' }), ev({ at: '2026-08-01T00:00:00Z' }), ev({ at: 'soon' }),
  ] }, NOW)
  assert.equal(events.length, 0)
  assert.equal(refused, 6)
})

test('never stores a uid, whatever the client sends', () => {
  const { events } = validateBatch({ events: [ev({ uid: 'someone-else' })] }, NOW)
  assert.equal(events[0].uid, null)
})

test("props go through the app's sanitiser: odd keys dropped, nested objects refused", () => {
  const { events } = validateBatch({ events: [ev({ props: { ok: 1, 'Bad Key': 2, nested: { a: 1 } } })] }, NOW)
  assert.deepEqual(Object.keys(events[0].props), ['ok'])
})

test(`caps a batch at ${MAX_EVENTS}`, () => {
  const { events, refused } = validateBatch({ events: Array.from({ length: 80 }, () => ev()) }, NOW)
  assert.equal(events.length, MAX_EVENTS)
  assert.equal(refused, 30)
})

test('survives junk bodies', () => {
  for (const b of [null, {}, { events: 'x' }, { events: [null, 5, 'a'] }]) assert.equal(validateBatch(b, NOW).events.length, 0)
})

test('the limiter allows a burst up to the limit, then refuses until the minute passes', () => {
  let t = 0
  const l = makeLimiter({ perMinute: 5, now: () => t })
  assert.equal(l.allow('v', 5), true)
  assert.equal(l.allow('v', 1), false)
  t = 61_000
  assert.equal(l.allow('v', 1), true)
  assert.equal(l.allow('other', 5), true, 'per key')
})
