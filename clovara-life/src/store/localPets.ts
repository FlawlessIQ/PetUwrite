/**
 * Pets on this device.
 *
 * This is where the app lived before there were accounts, and it is where the
 * signed-out demo still lives. It stays because "try it without signing up" is
 * the product's front door (SPEC §4.1: no account wall before the reveal), not
 * because it is a fallback.
 *
 * Moved out of App.tsx unchanged when the Firestore store arrived, so both
 * backends sit side by side and the validation below is not duplicated.
 */
import type { PetProfile } from '../data/types'
import { findBreed } from '../data/engine'

const STORAGE_KEY = 'clovara-life.pets.v1'

const OUTDOOR_VALUES = new Set(['indoor', 'indoor-outdoor', 'outdoor'])
const NEUTER_BANDS = new Set(['under-6m', '6-11m', '12-23m', '24m-plus', 'unsure'])

/** Optional field: absent is fine, present and wrong is not. */
const optionalOneOf = (v: unknown, allowed: Set<string>) =>
  v === undefined || (typeof v === 'string' && allowed.has(v))

/**
 * Anything coming out of localStorage is untrusted input. A pet saved by an
 * earlier build — or hand-edited, or half-written — must not be able to throw
 * during render, because `project()` throws on an unknown breed and there is no
 * way to recover from that mid-demo without devtools.
 */
export function isValidPet(p: unknown): p is PetProfile {
  if (!p || typeof p !== 'object') return false
  const x = p as Record<string, unknown>
  return (
    optionalOneOf(x.outdoorAccess, OUTDOOR_VALUES) &&
    optionalOneOf(x.neuterAgeBand, NEUTER_BANDS) &&
    typeof x.id === 'string' &&
    typeof x.name === 'string' &&
    x.name.trim().length > 0 &&
    (x.species === 'dog' || x.species === 'cat') &&
    typeof x.breedId === 'string' &&
    !!findBreed(x.breedId) &&
    typeof x.birthDate === 'string' &&
    !Number.isNaN(new Date(x.birthDate).getTime()) &&
    (x.neutered === undefined || typeof x.neutered === 'boolean') &&
    (x.birthDateApprox === undefined || typeof x.birthDateApprox === 'boolean') &&
    (x.conditionsReviewed === undefined || typeof x.conditionsReviewed === 'boolean') &&
    (x.knownSince === undefined || typeof x.knownSince === 'string') &&
    (x.lastReviewedAt === undefined || typeof x.lastReviewedAt === 'string') &&
    (x.lastReviewedRange === undefined ||
      (!!x.lastReviewedRange &&
        typeof x.lastReviewedRange === 'object' &&
        Number.isFinite((x.lastReviewedRange as Record<string, unknown>).low))) &&
    (x.photo === undefined ||
      (!!x.photo &&
        typeof x.photo === 'object' &&
        typeof (x.photo as Record<string, unknown>).avatarUrl === 'string')) &&
    (x.bodyConditionScore === undefined ||
      (typeof x.bodyConditionScore === 'number' && x.bodyConditionScore >= 1 && x.bodyConditionScore <= 5)) &&
    Array.isArray(x.conditionIds) &&
    typeof x.weightLb === 'number' &&
    Number.isFinite(x.weightLb) &&
    optionalOneOf(x.dental, new Set(['daily', 'weekly', 'rarely'])) &&
    optionalOneOf(x.activity, new Set(['low', 'moderate', 'high'])) &&
    optionalOneOf(x.diet, new Set(['measured', 'free-fed', 'unsure']))
  )
}

/**
 * Gives a pet saved before the annual review existed an anchor for it.
 *
 * Dated now, not backdated to their birthday: we genuinely do not know when we
 * last asked about this animal, and guessing "a year ago" would put a review in
 * front of everyone at once, on a screen none of them asked for. A year from
 * today is the honest and the quiet answer.
 *
 * Pure and exported so a test can prove it never touches a pet that already has
 * one — a backfill that overwrites is a backfill that resets everybody's clock
 * on every load.
 */
export function withReviewAnchor(pets: PetProfile[], now: Date): PetProfile[] {
  let changed = false
  const out = pets.map((p) => {
    if (p.knownSince) return p
    changed = true
    return { ...p, knownSince: now.toISOString() }
  })
  return changed ? out : pets
}

export function loadLocalPets(now: Date = new Date()): PetProfile[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return []
    const parsed = JSON.parse(raw)
    // Drop anything malformed rather than letting it reach the engine.
    if (!Array.isArray(parsed)) return []
    const pets = parsed.filter(isValidPet)
    const anchored = withReviewAnchor(pets, now)
    if (anchored !== pets) saveLocalPets(anchored)
    return anchored
  } catch {
    return []
  }
}

export function saveLocalPets(pets: PetProfile[]): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(pets))
  } catch {
    /* storage unavailable — the demo still works, it just won't persist */
  }
}

export function clearLocalPets(): void {
  try {
    localStorage.removeItem(STORAGE_KEY)
  } catch {
    /* nothing to do */
  }
}
