/**
 * The family circle (SPEC §4.3): invite someone into a household.
 *
 * Both halves run server-side on purpose. A client that could add a uid to a
 * household document could add ITSELF to any household whose id it guessed —
 * and household ids are in the URL of nothing, but they are in every pet path.
 * So the rules deny clients all access to `life_invites`, and membership is
 * changed only here, by the Admin SDK, after the code has been checked.
 */
const { HttpsError } = require('firebase-functions/v2/https')
const { FieldValue } = require('firebase-admin/firestore')
const { db, HOUSEHOLDS, ensureHousehold, trackServer } = require('./shared')

const INVITES = 'life_invites'
const INVITE_TTL_DAYS = 7

/**
 * Codes people read aloud and type on a phone.
 *
 * No 0/O/1/I/L — the characters that get mistyped when someone reads a code
 * over the kitchen table, which is exactly how this one will be shared.
 */
const ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'
function newCode() {
  let out = ''
  for (let i = 0; i < 8; i++) out += ALPHABET[Math.floor(Math.random() * ALPHABET.length)]
  return `${out.slice(0, 4)}-${out.slice(4)}`
}

async function createInvite(uid, email) {
  const household = await ensureHousehold(uid)
  if (Object.keys(household.members || {}).length >= 8) {
    throw new HttpsError('failed-precondition', 'A household tops out at eight people.')
  }

  const now = Date.now()
  const code = newCode()
  await db
    .collection(INVITES)
    .doc(code)
    .set({
      code,
      householdId: household.id,
      createdBy: uid,
      createdByEmail: email ?? null,
      createdAt: new Date(now).toISOString(),
      // Short-lived on purpose: an invite code is a key to everything known
      // about someone's pets, and a key that never expires is a key that leaks.
      expiresAt: new Date(now + INVITE_TTL_DAYS * 86400000).toISOString(),
      redeemedBy: null,
    })
  await trackServer(uid, 'tier1_field_added', { field: 'household_invite' })
  return { code, expiresInDays: INVITE_TTL_DAYS }
}

async function redeemInvite(uid, rawCode) {
  const code = String(rawCode || '')
    .trim()
    .toUpperCase()
  if (!/^[A-Z2-9]{4}-[A-Z2-9]{4}$/.test(code)) {
    throw new HttpsError('invalid-argument', "That code doesn't look right.")
  }

  const ref = db.collection(INVITES).doc(code)
  const snap = await ref.get()
  if (!snap.exists) throw new HttpsError('not-found', 'That invite has expired or never existed.')
  const invite = snap.data()

  if (invite.redeemedBy) {
    throw new HttpsError('failed-precondition', 'That invite has already been used.')
  }
  if (new Date(invite.expiresAt).getTime() < Date.now()) {
    throw new HttpsError('failed-precondition', 'That invite has expired. Ask for a fresh one.')
  }
  if (invite.createdBy === uid) {
    throw new HttpsError('failed-precondition', 'That is your own invite.')
  }

  const target = await db.collection(HOUSEHOLDS).doc(invite.householdId).get()
  if (!target.exists) throw new HttpsError('not-found', 'That household no longer exists.')
  if ((target.data().memberIds || []).includes(uid)) {
    throw new HttpsError('already-exists', 'You are already in that household.')
  }

  // One household per person in v1. ensureHousehold() finds a household by
  // array-contains and takes the first, so being in two would make "your
  // household" ambiguous and the pets that show up arbitrary.
  const existing = await db
    .collection(HOUSEHOLDS)
    .where('memberIds', 'array-contains', uid)
    .limit(1)
    .get()
  if (!existing.empty) {
    const mine = existing.docs[0]
    const pets = await mine.ref.collection('pets').limit(1).get()
    if (!pets.empty) {
      // Refusing beats merging badly. Two households of pets becoming one is a
      // real feature with real edge cases, and it is not this one.
      throw new HttpsError(
        'failed-precondition',
        'You already have pets of your own here. Joining a household with its own pets is not something we can do yet without risking losing one of them — tell us and we will sort it out by hand.',
      )
    }
    // Their household is empty, so leaving it costs nothing.
    await mine.ref.update({
      [`members.${uid}`]: FieldValue.delete(),
      memberIds: FieldValue.arrayRemove(uid),
    })
  }

  const joinedAt = new Date().toISOString()
  await target.ref.update({
    [`members.${uid}`]: { role: 'member', joinedAt },
    memberIds: FieldValue.arrayUnion(uid),
  })
  await ref.update({ redeemedBy: uid, redeemedAt: joinedAt })
  await trackServer(uid, 'tier1_field_added', { field: 'household_joined' })
  return { householdId: invite.householdId }
}

module.exports = { createInvite, redeemInvite, newCode, INVITES }
