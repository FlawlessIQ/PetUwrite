/**
 * Sitter Mode against the emulators (SPEC §6.6).
 *
 * This is the only unauthenticated read path in the product, so nearly every
 * assertion here is a refusal or a leak check. A sitter link should hand over a
 * fridge note and nothing else, should stop working, and should be impossible
 * to enumerate or forge.
 */
const PROJECT = 'pet-underwriter-ai'
const FN = `http://127.0.0.1:5001/${PROJECT}/us-central1`
const FS = `http://127.0.0.1:8080/v1/projects/${PROJECT}/databases/(default)/documents`
const AUTH = `http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1`

let failures = 0
const ok = (label, cond, detail = '') => {
  if (cond) console.log(`  ✓ ${label}`)
  else {
    failures++
    console.log(`  ✗ ${label}${detail ? ' — ' + detail : ''}`)
  }
}

const signUp = async () => {
  const r = await fetch(`${AUTH}/accounts:signUp?key=fake-api-key`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: `sit-${Math.random().toString(36).slice(2, 10)}@example.com`,
      password: 'emulator-password',
      returnSecureToken: true,
    }),
  }).then((x) => x.json())
  return { idToken: r.idToken, uid: r.localId }
}

const call = async (name, token, data = {}) => {
  const res = await fetch(`${FN}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ data }),
  })
  return res.json()
}

const householdOf = async (uid) => {
  const body = await fetch(`${FS}/households`, { headers: { Authorization: 'Bearer owner' } }).then(
    (r) => r.json(),
  )
  return (body.documents ?? []).find((d) =>
    (d.fields?.memberIds?.arrayValue?.values ?? []).some((v) => v.stringValue === uid),
  )
}

const f = (v) => ({ mapValue: { fields: { value: v } } })

console.log('\nSetting up a pet with care notes and a secret or two')
const alice = await signUp()
await call('createHouseholdInvite', alice.idToken) // ensures a household
const hh = await householdOf(alice.uid)
const hhId = hh.name.split('/').pop()
const petId = 'pet-sitter-1'

await fetch(`${FS}/households/${hhId}/pets?documentId=${petId}`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', Authorization: 'Bearer owner' },
  body: JSON.stringify({
    fields: {
      name: f({ stringValue: 'Scout' }),
      species: f({ stringValue: 'dog' }),
      breedId: f({ stringValue: 'labrador-retriever' }),
      weightLb: f({ integerValue: '68' }),
      conditionIds: f({
        arrayValue: { values: [{ stringValue: 'hip-dysplasia' }] },
      }),
      ownerEmail: f({ stringValue: 'secret-owner@example.com' }),
      careNotes: f({
        mapValue: {
          fields: {
            feeding: { stringValue: 'Two scoops, morning and evening.' },
            meds: { stringValue: 'Half a tablet with breakfast.' },
            vetName: { stringValue: 'Riverside Vets' },
            vetPhone: { stringValue: '01234 567890' },
          },
        },
      }),
    },
  }),
}).then((r) => r.json())

console.log('\nMaking a link')
const made = await call('createSitterLink', alice.idToken, { petId, days: 7 })
const token = made?.result?.token
ok('a token comes back', typeof token === 'string' && token.length >= 40, JSON.stringify(made).slice(0, 200))
ok('it is not a short human-readable code', !/^[A-Z2-9]{4}-[A-Z2-9]{4}$/.test(token || ''))
ok('it expires, and says when', made?.result?.expiresInDays === 7)

const anon = await fetch(`${FN}/createSitterLink`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ data: { petId } }),
}).then((r) => r.json())
ok('signed-out callers cannot mint links', anon?.error?.status === 'UNAUTHENTICATED')

console.log('\nThe client can never see the links collection')
const direct = await fetch(`${FS}/life_sitter_links`).then((r) => r.status)
ok('reading it straight from Firestore is denied', direct === 403, `status ${direct}`)

console.log('\nWhat a sitter actually gets')
const card = await fetch(`${FN}/sitterCard?t=${encodeURIComponent(token)}`).then((r) => r.json())
ok('the card loads with no sign-in at all', card?.card?.name === 'Scout', JSON.stringify(card).slice(0, 200))
ok('it carries the feeding note', /Two scoops/.test(card.card.feeding || ''))
ok('and the vet phone, for tapping', card.card.vetPhone === '01234 567890')

const blob = JSON.stringify(card)
ok('it does NOT carry the owner email', !blob.includes('secret-owner@example.com'))
ok('it does NOT carry a diagnosis', !blob.includes('hip-dysplasia'))
ok('it does NOT carry the household id', !blob.includes(hhId))
ok('it does NOT carry the weight or the projection', !/weightLb|healthyYears|lastReviewed/.test(blob))
ok(
  'the card has only the fields a fridge note would',
  Object.keys(card.card).every((k) =>
    [
      'name',
      'species',
      'breedId',
      'photoUrl',
      'feeding',
      'medication',
      'quirks',
      'vetName',
      'vetPhone',
      'emergencyName',
      'emergencyPhone',
    ].includes(k),
  ),
  Object.keys(card.card).join(','),
)

console.log('\nTokens cannot be guessed or probed')
for (const bad of ['', 'x', 'not-a-real-token-but-long-enough-to-look-plausible', token.slice(0, -1)]) {
  const r = await fetch(`${FN}/sitterCard?t=${encodeURIComponent(bad)}`)
  ok(`a wrong token gets 404, not a hint (${bad.slice(0, 12) || 'empty'})`, r.status === 404)
}

console.log('\nAnother household cannot touch it')
const bob = await signUp()
await call('createHouseholdInvite', bob.idToken)
const bobList = await call('listSitterLinks', bob.idToken)
ok(
  'a stranger listing links sees none of Alice\'s',
  (bobList?.result?.links ?? []).every((l) => l.token !== token),
  JSON.stringify(bobList).slice(0, 160),
)
await call('revokeSitterLink', bob.idToken, { token })
const stillLive = await fetch(`${FN}/sitterCard?t=${encodeURIComponent(token)}`)
ok('and a stranger cannot revoke it either', stillLive.status === 200)

console.log('\nRevoking')
const mine = await call('listSitterLinks', alice.idToken)
ok('the owner can list their own links', (mine?.result?.links ?? []).some((l) => l.token === token))
await call('revokeSitterLink', alice.idToken, { token })
const afterRevoke = await fetch(`${FN}/sitterCard?t=${encodeURIComponent(token)}`)
ok('a revoked link stops working immediately', afterRevoke.status === 404)
ok(
  'and looks identical to one that never existed',
  afterRevoke.status === (await fetch(`${FN}/sitterCard?t=neverexisted-aaaaaaaaaaaaaaaaaaaaaaaa`)).status,
)

console.log('\nExpiry is enforced on the server')
const made2 = await call('createSitterLink', alice.idToken, { petId, days: 7 })
const token2 = made2.result.token
await fetch(`${FS}/life_sitter_links/${token2}?updateMask.fieldPaths=expiresAt`, {
  method: 'PATCH',
  headers: { 'Content-Type': 'application/json', Authorization: 'Bearer owner' },
  body: JSON.stringify({ fields: { expiresAt: { stringValue: '2020-01-01T00:00:00.000Z' } } }),
}).then((r) => r.json())
const expired = await fetch(`${FN}/sitterCard?t=${encodeURIComponent(token2)}`)
ok('an expired link is refused by the server, not the client', expired.status === 404)

console.log('\nTTL is bounded')
const long = await call('createSitterLink', alice.idToken, { petId, days: 3650 })
ok('a ten-year link is capped', long?.result?.expiresInDays <= 30, String(long?.result?.expiresInDays))
const zero = await call('createSitterLink', alice.idToken, { petId, days: 0 })
ok('and a zero-day link still lasts at least a day', zero?.result?.expiresInDays >= 1)

console.log(`\n${failures === 0 ? 'sitter verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
