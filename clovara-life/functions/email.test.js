const test = require('node:test')
const assert = require('node:assert/strict')
const { TEMPLATES, sendTemplate } = require('./email')

const renderAll = () => [
  TEMPLATES.welcome({ petName: 'Max' }),
  TEMPLATES.trialEnding({ petName: 'Max', daysLeft: 3, amountDisplay: '$22.99' }),
]

test('every template has a subject and a body', () => {
  for (const t of renderAll()) {
    assert.ok(t.subject.length > 5, `subject too short: ${t.subject}`)
    assert.ok(t.text.length > 60)
  }
})

test('copy honours the vocabulary rules in docs/VISION.md', () => {
  // "never lifecycle, platform, or standalone wellness in customer copy" —
  // these are the words that make a pet sound like a subscription funnel.
  const banned = [/\blifecycle\b/i, /\bplatform\b/i]
  for (const t of renderAll()) {
    const all = `${t.subject} ${t.text}`
    for (const re of banned) {
      assert.ok(!re.test(all), `banned word ${re} in: ${t.subject}`)
    }
  }
})

test('never promises a longer life', () => {
  // "never promise longer life" — help, on track for, more good years.
  const promises = [/live longer/i, /longer life/i, /extend .{0,12}life/i, /add years/i]
  for (const t of renderAll()) {
    const all = `${t.subject} ${t.text}`
    for (const re of promises) {
      assert.ok(!re.test(all), `life promise ${re} in: ${t.subject}`)
    }
  }
})

test('carries the not-veterinary-advice line', () => {
  for (const t of renderAll()) {
    assert.match(t.text, /not veterinary\s*\n?advice/i)
  }
})

test('the trial-ending note says what is NOT lost, not only what is', () => {
  // Someone deciding whether to keep paying deserves to know the plan stays.
  const t = TEMPLATES.trialEnding({ petName: 'Max', daysLeft: 1, amountDisplay: '$22.99' })
  assert.match(t.text, /stay where they are/i)
  assert.match(t.subject, /tomorrow/)
})

test('day counts read naturally at the edges', () => {
  assert.match(TEMPLATES.trialEnding({ daysLeft: 0 }).subject, /ends today/)
  assert.match(TEMPLATES.trialEnding({ daysLeft: 1 }).subject, /ends tomorrow/)
  assert.match(TEMPLATES.trialEnding({ daysLeft: 5 }).subject, /in 5 days/)
})

test('a pet with no name still reads as a sentence', () => {
  for (const t of [TEMPLATES.welcome({}), TEMPLATES.trialEnding({ daysLeft: 2 })]) {
    assert.ok(!/undefined|null/.test(`${t.subject} ${t.text}`))
  }
})

test('sendTemplate never throws into its caller', async () => {
  // A webhook must not 500 — and be retried by Stripe forever — because an
  // email failed to render.
  for (const call of [
    sendTemplate('nope', 'a@b.com', {}),
    sendTemplate('welcome', null, {}),
    sendTemplate('welcome', 'a@b.com', null),
  ]) {
    const r = await call
    assert.equal(typeof r.delivered, 'boolean')
    assert.equal(r.delivered, false)
  }
})

test('the console sender reports that it did not deliver', async () => {
  const r = await sendTemplate('welcome', 'a@b.com', { petName: 'Max' })
  assert.equal(r.provider, 'console')
  assert.equal(r.delivered, false, 'P0 must not claim to have sent anything')
})
