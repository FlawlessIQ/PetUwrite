/**
 * The shape Clovara Life stores in Firestore.
 *
 * Deliberately NOT the same shape the engine consumes. The engine takes a flat
 * `PetProfile` and stays pure (invariant 7); Firestore stores every owner-
 * supplied field wrapped with provenance (invariant 8), because "who said this
 * and how do we know" is the question the whole data-capture system in SPEC §4
 * is built to answer. `profileFromFirestore()` is the thin seam between them.
 *
 * Layout follows SPEC §7:
 *   households/{householdId}                     → Household
 *   households/{householdId}/pets/{petId}        → StoredPet
 *   households/{householdId}/pets/{petId}/records/*   (P1)
 *   households/{householdId}/pets/{petId}/events/*    (P1)
 */
import type {
  ActivityLevel,
  PetProfile,
  BodyConditionScore,
  DentalRoutine,
  DietQuality,
  NeuterAgeBand,
  OutdoorAccess,
  Sex,
  Species,
} from './types'

/**
 * How a stored value came to be known. Invariant 8: anything extracted becomes
 * structured data only after the owner confirms it, and the record of that
 * confirmation is this field — never dropped, never inferred later.
 */
export type Provenance = 'owner_declared' | 'extracted_confirmed' | 'device' | 'vet_verified'

export const PROVENANCES: Provenance[] = [
  'owner_declared',
  'extracted_confirmed',
  'device',
  'vet_verified',
]

/** Every owner-supplied value carries its own history. */
export interface Field<T> {
  value: T
  provenance: Provenance
  /** ISO 8601. */
  updatedAt: string
  /** uid of whoever last set it. */
  updatedBy: string
}

/**
 * A pet as stored.
 *
 * Only the Tier-0 fields (SPEC §4.1) are required — species, breed, name,
 * birthDate. Everything else is optional because invariant 9 says "I don't
 * know" is always an answer, and a pet with four fields answered must project
 * and render exactly as well as one with twelve.
 */
export interface StoredPet {
  id: string
  householdId: string
  createdAt: string
  createdBy: string
  /** Set when the pet came in from a pre-account localStorage session. */
  importedFrom?: 'localStorage'

  // ── Tier 0 ───────────────────────────────────────────────────────────────
  name: Field<string>
  species: Field<Species>
  breedId: Field<string>
  birthDate: Field<string>
  birthDateApprox?: Field<boolean>

  // ── Tier 1 — every one optional ──────────────────────────────────────────
  sex?: Field<Sex>
  neutered?: Field<boolean>
  conditionsReviewed?: Field<boolean>
  /** ISO dates anchoring the annual re-projection (SPEC §4.3). */
  knownSince?: Field<string>
  lastReviewedAt?: Field<string>
  lastReviewedRange?: Field<{ low: number; high: number }>
  socialStamps?: Field<string[]>
  vaccineRecords?: Field<{ doseId: string; givenOn: string }[]>
  careNotes?: Field<Record<string, string>>
  neuterAgeBand?: Field<NeuterAgeBand>
  weightLb?: Field<number>
  bodyConditionScore?: Field<BodyConditionScore>
  conditionIds?: Field<string[]>
  activity?: Field<ActivityLevel>
  dental?: Field<DentalRoutine>
  diet?: Field<DietQuality>
  outdoorAccess?: Field<OutdoorAccess>
  photo?: Field<PetProfile['photo']>
  headline?: Field<string>
}

export type HouseholdRole = 'owner' | 'member'

export interface HouseholdMember {
  role: HouseholdRole
  joinedAt: string
}

/**
 * A household owns pets; users belong to households (SPEC §7).
 *
 * `members` carries the roles. `memberIds` duplicates its keys as an array
 * purely so the security rules and the "find my household" query can both use
 * it — Firestore cannot query map keys. The duplication is written on every
 * membership change and asserted in tests rather than trusted.
 */
export interface Household {
  id: string
  createdAt: string
  createdBy: string
  members: Record<string, HouseholdMember>
  memberIds: string[]
}

// ───────────────────────────────────────────────────────────────────────────
// Guards. Everything out of Firestore is untrusted input, exactly like
// everything out of localStorage — a document written by an older build, a
// half-finished write, or a hand-edit must never reach `project()`, which
// throws on an unknown breed.
// ───────────────────────────────────────────────────────────────────────────

const isIso = (v: unknown): v is string =>
  typeof v === 'string' && v.length > 0 && !Number.isNaN(new Date(v).getTime())

export function isField(v: unknown): v is Field<unknown> {
  if (!v || typeof v !== 'object') return false
  const f = v as Record<string, unknown>
  return (
    'value' in f &&
    typeof f.provenance === 'string' &&
    (PROVENANCES as string[]).includes(f.provenance) &&
    isIso(f.updatedAt) &&
    typeof f.updatedBy === 'string'
  )
}

/** A typed read that drops anything malformed rather than trusting it. */
export function fieldValue<T>(f: unknown, ok: (v: unknown) => v is T): T | undefined {
  if (!isField(f)) return undefined
  return ok(f.value) ? f.value : undefined
}

export const isString = (v: unknown): v is string => typeof v === 'string'
export const isBoolean = (v: unknown): v is boolean => typeof v === 'boolean'
export const isFiniteNumber = (v: unknown): v is number =>
  typeof v === 'number' && Number.isFinite(v)
export const isStringArray = (v: unknown): v is string[] =>
  Array.isArray(v) && v.every((x) => typeof x === 'string')
export const oneOf =
  <T extends string>(...allowed: T[]) =>
  (v: unknown): v is T =>
    typeof v === 'string' && (allowed as string[]).includes(v)

export const isSpecies = oneOf<Species>('dog', 'cat')
export const isSex = oneOf<Sex>('male', 'female')
export const isActivity = oneOf<ActivityLevel>('low', 'moderate', 'high')
export const isDental = oneOf<DentalRoutine>('daily', 'weekly', 'rarely')
export const isDiet = oneOf<DietQuality>('measured', 'free-fed', 'unsure')
export const isOutdoor = oneOf<OutdoorAccess>('indoor', 'indoor-outdoor', 'outdoor')
export const isBodyScore = (v: unknown): v is BodyConditionScore =>
  v === 1 || v === 2 || v === 3 || v === 4 || v === 5

export const isNeuterBand = oneOf<NeuterAgeBand>(
  'under-6m',
  '6-11m',
  '12-23m',
  '24m-plus',
  'unsure',
)
