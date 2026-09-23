/**
 * The family circle against the emulators (SPEC §4.3).
 *
 * Every assertion that matters here is a refusal: an invite that can be reused,
 * guessed, self-redeemed or read from the client is not a family circle, it is
 * a way into someone's pet records.
 */
import { execSync } from 'node:child_process'

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
      email: `hh-${Math.random().toString(36).slice(2, 10)}@example.com`,
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
  const body = await fetch(`${FS}/households`, {
    headers: { Authorization: 'Bearer owner' },
  }).then((r) => r.json())
  return (body.documents ?? []).find((d) =>
    (d.fields?.memberIds?.arrayValue?.values ?? []).some((v) => v.stringValue === uid),
  )
}

console.log('\nInviting')
const alice = await signUp()
// Give Alice a household by asking for an invite (which ensures one).
const invited = await call('createHouseholdInvite', alice.idToken)
const code = invited?.result?.code
ok('an invite code comes back', /^[A-Z2-9]{4}-[A-Z2-9]{4}$/.test(code || ''), JSON.stringify(invited).slice(0, 160))
ok('it expires, and says when', invited?.result?.expiresInDays === 7)

const anon = await fetch(`${FN}/createHouseholdInvite`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ data: {} }),
}).then((r) => r.json())
ok('signed-out callers cannot mint invites', anon?.error?.status === 'UNAUTHENTICATED')

console.log('\nThe client can never see invites')
const readInvites = await fetch(`${FS}/life_invites?pageSize=1`).then((r) => r.status)
ok('anonymous read of life_invites is refused', readInvites === 403, `HTTP ${readInvites}`)

console.log('\nJoining')
const bob = await signUp()
const selfRedeem = await call('redeemHouseholdInvite', alice.idToken, { code })
ok('you cannot redeem your own invite', selfRedeem?.error?.status === 'FAILED_PRECONDITION', JSON.stringify(selfRedeem).slice(0, 140))

const bad = await call('redeemHouseholdInvite', bob.idToken, { code: 'ZZZZ-9999' })
ok('an unknown code is refused', bad?.error?.status === 'NOT_FOUND')

const malformed = await call('redeemHouseholdInvite', bob.idToken, { code: 'nope' })
ok('a malformed code is refused before any lookup', malformed?.error?.status === 'INVALID_ARGUMENT')

const joined = await call('redeemHouseholdInvite', bob.idToken, { code })
ok('a valid code joins the household', !!joined?.result?.householdId, JSON.stringify(joined).slice(0, 160))

const hh = await householdOf(bob.uid)
const ids = (hh?.fields?.memberIds?.arrayValue?.values ?? []).map((v) => v.stringValue)
ok('both people are now in one household', ids.includes(alice.uid) && ids.includes(bob.uid), ids.join(','))
ok('memberIds and members stay in step', Object.keys(hh?.fields?.members?.mapValue?.fields ?? {}).sort().join() === ids.slice().sort().join())
ok('the joiner is a member, not an owner', hh?.fields?.members?.mapValue?.fields?.[bob.uid]?.mapValue?.fields?.role?.stringValue === 'member')

console.log('\nAn invite is single-use')
const carol = await signUp()
const reuse = await call('redeemHouseholdInvite', carol.idToken, { code })
ok('the same code cannot be used twice', reuse?.error?.status === 'FAILED_PRECONDITION', JSON.stringify(reuse).slice(0, 140))

const again = await call('redeemHouseholdInvite', bob.idToken, { code })
ok('someone already in the household is told so', !!again?.error, JSON.stringify(again).slice(0, 120))

console.log('\nSomeone with pets of their own is refused, not merged')
const dave = await signUp()
const daveInvite = await call('createHouseholdInvite', dave.idToken)
const daveHh = await householdOf(dave.uid)
await fetch(`${FS}/households/${daveHh.name.split('/').pop()}/pets?documentId=pet-x`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', Authorization: 'Bearer owner' },
  body: JSON.stringify({
    fields: {
      id: { stringValue: 'pet-x' },
      name: { mapValue: { fields: { value: { stringValue: 'Rex' }, provenance: { stringValue: 'owner_declared' }, updatedAt: { stringValue: new Date().toISOString() }, updatedBy: { stringValue: dave.uid } } } },
    },
  }),
})
const alicesSecond = await call('createHouseholdInvite', alice.idToken)
const merge = await call('redeemHouseholdInvite', dave.idToken, { code: alicesSecond?.result?.code })
ok('joining with pets of your own is refused rather than merged badly', merge?.error?.status === 'FAILED_PRECONDITION')
ok('and the refusal explains what to do', /sort it out by hand/i.test(merge?.error?.message ?? ''), merge?.error?.message?.slice(0, 80))
void daveInvite

console.log(`\n${failures === 0 ? 'household verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
