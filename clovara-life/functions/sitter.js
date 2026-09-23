/**
 * Sitter Mode (SPEC §6.6): an expiring, revocable, read-only link to the
 * handful of things somebody minding an animal actually needs.
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * THE SECURITY MODEL, BECAUSE THIS IS THE ONLY UNAUTHENTICATED READ PATH IN
 * THE PRODUCT.
 *
 * 1. THE TOKEN IS THE CREDENTIAL. It is 32 bytes from a CSPRNG, base64url —
 *    not the invite-code alphabet, which is short and human-readable on
 *    purpose because somebody reads it across a kitchen table. This one is
 *    pasted, never dictated, so it can be long and unguessable instead.
 *
 * 2. CLIENTS NEVER TOUCH THE COLLECTION. `life_sitter_links` is deny-all in
 *    the rules, in both directions. Creation, reading and revocation all go
 *    through the Admin SDK here, so a client cannot enumerate links, cannot
 *    forge one, and cannot read one belonging to a household it is not in.
 *
 * 3. THE CARD IS ASSEMBLED SERVER-SIDE AND IS DELIBERATELY SMALL. Only what a
 *    sitter needs: name, species, breed, photo, feeding, medication, quirks,
 *    the vet and an emergency contact. NOT the projection, NOT conditions as a
 *    medical history, NOT the owner's email, NOT the household id, NOT
 *    anything about membership or billing. A link that leaks should leak a
 *    fridge note, not a record.
 *
 * 4. EXPIRY AND REVOCATION ARE ENFORCED HERE, not in the client. Seven days by
 *    default. A revoked or expired link returns the same 404 as one that never
 *    existed, so the endpoint cannot be used to test whether a token was ever
 *    real.
 * ═══════════════════════════════════════════════════════════════════════════
 */
const crypto = require('node:crypto')
const { HttpsError } = require('firebase-functions/v2/https')
const { db, HOUSEHOLDS, ensureHousehold, trackServer } = require('./shared')

const SITTER_LINKS = 'life_sitter_links'
const DEFAULT_TTL_DAYS = 7
const MAX_TTL_DAYS = 30

/** 32 bytes of CSPRNG, base64url. Pasted, never dictated. */
function newToken() {
  return crypto.randomBytes(32).toString('base64url')
}

/**
 * What a sitter is shown. Everything here is something an owner would write on
 * a fridge note; nothing here is anything they would not hand to a neighbour.
 */
function cardFromPet(pet) {
  const notes = pet.careNotes?.value ?? pet.careNotes ?? {}
  const val = (f) => (f && typeof f === 'object' && 'value' in f ? f.value : f)
  return {
    name: val(pet.name) ?? 'Their pet',
    species: val(pet.species) ?? null,
    breedId: val(pet.breedId) ?? null,
    photoUrl: val(pet.photo)?.avatarUrl ?? null,
    feeding: notes.feeding ?? null,
    medication: notes.meds ?? null,
    quirks: notes.quirks ?? null,
    vetName: notes.vetName ?? null,
    vetPhone: notes.vetPhone ?? null,
    emergencyName: notes.emergencyName ?? null,
    emergencyPhone: notes.emergencyPhone ?? null,
  }
}

async function createSitterLink(uid, petId, days) {
  const household = await ensureHousehold(uid)
  const ttl = Math.min(MAX_TTL_DAYS, Math.max(1, Number(days) || DEFAULT_TTL_DAYS))

  const petRef = db.collection(HOUSEHOLDS).doc(household.id).collection('pets').doc(String(petId))
  const petSnap = await petRef.get()
  if (!petSnap.exists) throw new HttpsError('not-found', 'We could not find that pet.')

  const token = newToken()
  const now = Date.now()
  await db
    .collection(SITTER_LINKS)
    .doc(token)
    .set({
      token,
      householdId: household.id,
      petId: String(petId),
      createdBy: uid,
      createdAt: new Date(now).toISOString(),
      expiresAt: new Date(now + ttl * 86400000).toISOString(),
      revokedAt: null,
    })
  await trackServer(uid, 'tier1_field_added', { field: 'sitter_link' })
  return { token, expiresInDays: ttl }
}

async function revokeSitterLink(uid, token) {
  const household = await ensureHousehold(uid)
  const ref = db.collection(SITTER_LINKS).doc(String(token || ''))
  const snap = await ref.get()
  // Silently succeed for a link that is not theirs or does not exist: telling
  // somebody "that link belongs to another household" confirms it is real.
  if (!snap.exists || snap.data().householdId !== household.id) return { revoked: true }
  await ref.update({ revokedAt: new Date().toISOString() })
  return { revoked: true }
}

async function listSitterLinks(uid) {
  const household = await ensureHousehold(uid)
  const snap = await db
    .collection(SITTER_LINKS)
    .where('householdId', '==', household.id)
    .limit(50)
    .get()
  const now = Date.now()
  return snap.docs
    .map((d) => d.data())
    .filter((l) => !l.revokedAt && Date.parse(l.expiresAt) > now)
    .map((l) => ({ token: l.token, petId: l.petId, expiresAt: l.expiresAt, createdAt: l.createdAt }))
}

/**
 * The public read. Returns null for expired, revoked, and never-existed alike —
 * a different answer for each would make this an oracle for guessing tokens.
 */
async function readSitterCard(token) {
  const raw = String(token || '')
  if (!/^[A-Za-z0-9_-]{16,128}$/.test(raw)) return null

  const snap = await db.collection(SITTER_LINKS).doc(raw).get()
  if (!snap.exists) return null
  const link = snap.data()
  if (link.revokedAt) return null
  if (!(Date.parse(link.expiresAt) > Date.now())) return null

  const petSnap = await db
    .collection(HOUSEHOLDS)
    .doc(link.householdId)
    .collection('pets')
    .doc(link.petId)
    .get()
  if (!petSnap.exists) return null

  return { card: cardFromPet(petSnap.data()), expiresAt: link.expiresAt }
}

module.exports = {
  createSitterLink,
  revokeSitterLink,
  listSitterLinks,
  readSitterCard,
  cardFromPet,
  newToken,
  SITTER_LINKS,
  DEFAULT_TTL_DAYS,
  MAX_TTL_DAYS,
}
