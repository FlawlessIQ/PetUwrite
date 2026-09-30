/**
 * The daily run against the Firestore emulator. Skipped unless
 * FIRESTORE_EMULATOR_HOST is set — `npm run test:moments` sets it up.
 */
const test = require('node:test')
const assert = require('node:assert/strict')

const ON = !!process.env.FIRESTORE_EMULATOR_HOST
test('the daily run sends what is due, once, and only to people who opted in', { skip: !ON && 'no emulator' }, async () => {
  const { initializeApp, getApps } = require('firebase-admin/app')
  const { getFirestore } = require('firebase-admin/firestore')
  const { runMoments } = require('./moments-job')
  const app = getApps()[0] || initializeApp({ projectId: 'demo-moments' })
  const db = getFirestore(app)

  const NOW = new Date('2026-09-30T12:00:00Z')
  const f = (v) => ({ value: v, provenance: 'owner_declared', updatedAt: NOW.toISOString(), updatedBy: 'u-in' })
  const pet = {
    createdBy: 'u-in', name: f('Bruno'), species: f('dog'), breedId: f('labrador-retriever'), sex: f('male'),
    conditionIds: f([]), birthDate: f(new Date(NOW - 71 * 86400000).toISOString().slice(0, 10)),
    knownSince: f(new Date(NOW - 20 * 3600000).toISOString()),
  }
  await db.doc('households/h-in').set({ memberIds: ['u-in'] })
  await db.doc('households/h-in/pets/p1').set(pet)
  await db.doc('households/h-out').set({ memberIds: ['u-out'] })
  await db.doc('households/h-out/pets/p2').set({ ...pet, createdBy: 'u-out' })
  await db.doc('life_prefs/u-in').set({ moments: true, unsubscribeToken: 'tok-in' })
  await db.doc('life_prefs/u-out').set({ moments: false, unsubscribeToken: 'tok-out' })

  const mail = []
  const deps = {
    db, now: NOW, preferencesUrl: 'https://example.test/emailPreferences',
    emailOf: async (uid) => `${uid}@example.test`,
    send: async (name, to, data, headers) => { mail.push({ name, to, subject: data.subject, headers }); return { delivered: false } },
    track: async () => {},
  }
  const first = await runMoments(deps)
  assert.ok(first.sent >= 1, 'something is due for a puppy home since yesterday')
  assert.ok(mail.every((m) => m.to === 'u-in@example.test'), 'only the person who opted in')
  assert.ok(mail.some((m) => /first night/.test(m.subject)))
  assert.match(mail[0].headers['List-Unsubscribe'], /\?t=tok-in>$/)

  const sent = (await db.doc('life_prefs/u-in').get()).get('sent')
  assert.ok(sent && Object.keys(sent).some((k) => k === 'p1|first-nights'), 'recorded as sent')

  mail.length = 0
  const second = await runMoments(deps)
  assert.equal(second.sent, 0, 'the same morning twice sends nothing new')
  assert.equal(mail.length, 0)
})
