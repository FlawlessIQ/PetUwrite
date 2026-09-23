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
    Array.isArray(x.conditionIds) &&
    typeof x.weightLb === 'number' &&
    Number.isFinite(x.weightLb) &&
    optionalOneOf(x.dental, new Set(['daily', 'weekly', 'rarely'])) &&
    optionalOneOf(x.activity, new Set(['low', 'moderate', 'high'])) &&
    optionalOneOf(x.diet, new Set(['measured', 'free-fed', 'unsure']))
  )
}

export function loadLocalPets(): PetProfile[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return []
    const parsed = JSON.parse(raw)
    // Drop anything malformed rather than letting it reach the engine.
    return Array.isArray(parsed) ? parsed.filter(isValidPet) : []
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
