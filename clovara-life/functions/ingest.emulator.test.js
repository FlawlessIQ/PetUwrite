/**
 * lifeIngest end to end: the real HTTP function in the Functions emulator,
 * writing to the Firestore emulator. Skipped unless both are running —
 * `npm run test:ingest` starts them.
 */
const test = require('node:test')
const assert = require('node:assert/strict')

const ON = !!process.env.FIRESTORE_EMULATOR_HOST && !!process.env.FIREBASE_EMULATOR_HUB
const URL_ = process.env.INGEST_URL || 'http://127.0.0.1:5001/pet-underwriter-ai/us-central1/lifeIngest'
const post = (body, origin = 'https://clovara-life.web.app') =>
  fetch(URL_, { method: 'POST', headers: { 'Content-Type': 'text/plain', Origin: origin }, body: typeof body === 'string' ? body : JSON.stringify(body) })

test('an anonymous visit lands in life_events, with no uid, and nothing else gets in', { skip: !ON && 'no emulators' }, async () => {
  const { initializeApp, getApps } = require('firebase-admin/app')
  const { getFirestore } = require('firebase-admin/firestore')
  const db = getFirestore(getApps()[0] || initializeApp({ projectId: 'pet-underwriter-ai' }))
  const visitorId = `visitor-${Date.now()}`
  const at = new Date().toISOString()
  const ev = { name: 'first_visit', props: { utm_source: 'rescue' }, at, visitorId, sessionId: 'session-test-1', build: 't', uid: 'impostor' }

  const res = await post({ events: [ev, { ...ev, name: 'not_an_event' }] })
  assert.equal(res.status, 202)
  assert.deepEqual(await res.json(), { stored: 1, refused: 1 })
  const snap = await db.collection('life_events').where('visitorId', '==', visitorId).get()
  assert.equal(snap.size, 1)
  const stored = snap.docs[0].data()
  assert.equal(stored.uid, null, 'never the uid the client claimed')
  assert.equal(stored.anon, true)
  assert.equal(stored.props.utm_source, 'rescue')

  assert.equal((await post({ events: [ev] }, 'https://evil.example')).status, 403, 'other sites are refused')
  assert.equal((await post('not json')).status, 400)
  assert.equal((await fetch(URL_, { headers: { Origin: 'https://clovara-life.web.app' } })).status, 403, 'GET does nothing')
})
