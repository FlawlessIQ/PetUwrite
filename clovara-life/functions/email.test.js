const test = require('node:test')
const assert = require('node:assert/strict')
const { TEMPLATES, sendTemplate } = require('./email')

const renderAll = () => [
  TEMPLATES.welcome({ petName: 'Max' }),
  TEMPLATES.trialEnding({ petName: 'Max', daysLeft: 3, amountDisplay: '$22.99' }),
  TEMPLATES.planSaved({ petName: 'Max' }),
  TEMPLATES.moment({
    petName: 'Max',
    subject: 'Two weeks of the easy part left for Max',
    lines: ['Until about 14 weeks old, a puppy accepts new things far more readily.', 'Nothing is required.'],
    preferencesUrl: 'https://example.test/prefs?t=abc',
  }),
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

test('a moment email always carries the way out and the address placeholder', () => {
  const t = TEMPLATES.moment({ petName: 'Max', subject: 's', lines: ['a'], preferencesUrl: 'https://example.test/p?t=1' })
  assert.match(t.text, /Turn them off: https:\/\/example\.test\/p\?t=1/)
  assert.match(t.text, /because you asked for reminders about Max/)
  assert.match(t.text, /LEGAL-REVIEW: postal address/)
})

test('a moment email says what the engine says, in order, as paragraphs', () => {
  const t = TEMPLATES.moment({ petName: 'Max', subject: 'Subject line', lines: ['First.', 'Second.'] })
  assert.equal(t.subject, 'Subject line')
  assert.match(t.text, /^First\.\n\nSecond\./)
})

test('plan-saved is transactional: no unsubscribe, no offer', () => {
  const t = TEMPLATES.planSaved({ petName: 'Max' })
  assert.doesNotMatch(t.text, /Turn them off|trial|\$\d/)
})

test('headers reach the sender (List-Unsubscribe for one-click)', async () => {
  const r = await sendTemplate('moment', 'a@example.test', { petName: 'Max', lines: ['x'] }, { 'List-Unsubscribe': '<https://example.test/u>' })
  assert.equal(r.provider, 'console')
})

// ── The SendGrid sender ────────────────────────────────────────────────────
const { makeSendgridSender, parseFrom } = require('./email')

const fakeFetch = (status = 202, body = '') => {
  const calls = []
  const fn = async (url, init) => {
    calls.push({ url, init, body: JSON.parse(init.body) })
    return { status, ok: status >= 200 && status < 300, text: async () => body, headers: { get: (h) => (h === 'x-message-id' ? 'msg-1' : null) } }
  }
  fn.calls = calls
  return fn
}

test('sends plain text through the v3 API, with the headers it was given', async () => {
  const f = fakeFetch()
  const s = makeSendgridSender({ apiKey: 'SG.test', from: 'Clovara <hello@example.test>', fetchImpl: f })
  const r = await s.send({ to: 'owner@example.test', subject: 'Hi', text: 'Body', headers: { 'List-Unsubscribe': '<https://x/u>' } })
  assert.deepEqual(r, { delivered: true, provider: 'sendgrid', id: 'msg-1' })
  const { url, init, body } = f.calls[0]
  assert.equal(url, 'https://api.sendgrid.com/v3/mail/send')
  assert.equal(init.headers.Authorization, 'Bearer SG.test')
  assert.deepEqual(body.from, { email: 'hello@example.test', name: 'Clovara' })
  assert.deepEqual(body.personalizations, [{ to: [{ email: 'owner@example.test' }] }])
  assert.deepEqual(body.content, [{ type: 'text/plain', value: 'Body' }])
  assert.equal(body.headers['List-Unsubscribe'], '<https://x/u>')
})

test('switches off open and click tracking — the unsubscribe link must reach us, and nobody else learns who opened what', async () => {
  const f = fakeFetch()
  await makeSendgridSender({ apiKey: 'k', from: 'a@example.test', fetchImpl: f }).send({ to: 'b@example.test', subject: 's', text: 't' })
  const t = f.calls[0].body.tracking_settings
  assert.equal(t.click_tracking.enable, false)
  assert.equal(t.open_tracking.enable, false)
})

test('refuses to run half-configured rather than dropping mail', async () => {
  await assert.rejects(makeSendgridSender({ from: 'a@example.test', fetchImpl: fakeFetch() }).send({ to: 'b', subject: 's', text: 't' }), /SENDGRID_API_KEY/)
  await assert.rejects(makeSendgridSender({ apiKey: 'k', fetchImpl: fakeFetch() }).send({ to: 'b', subject: 's', text: 't' }), /EMAIL_FROM/)
})

test('a rejection from SendGrid is an error that says why', async () => {
  const s = makeSendgridSender({ apiKey: 'k', from: 'a@example.test', fetchImpl: fakeFetch(403, '{"errors":[{"message":"sender not verified"}]}') })
  await assert.rejects(s.send({ to: 'b@example.test', subject: 's', text: 't' }), /SendGrid 403: .*sender not verified/)
})

test('reads a from line with or without a display name', () => {
  assert.deepEqual(parseFrom('Clovara <hello@clovara.test>'), { email: 'hello@clovara.test', name: 'Clovara' })
  assert.deepEqual(parseFrom('hello@clovara.test'), { email: 'hello@clovara.test' })
})

test('without EMAIL_PROVIDER=sendgrid nothing leaves: the console sender answers', async () => {
  const before = process.env.EMAIL_PROVIDER
  delete process.env.EMAIL_PROVIDER
  const r = await sendTemplate('planSaved', 'a@example.test', { petName: 'Max' })
  assert.equal(r.provider, 'console')
  if (before !== undefined) process.env.EMAIL_PROVIDER = before
})
