/**
 * The seam between what we store and what the engine consumes (SPEC §7).
 *
 * Pure in both directions. No IO, no clock unless injected — the engine's own
 * discipline (invariant 7) applies here too, because this is the function that
 * decides what the engine is told, and a projection that silently depends on a
 * wall clock or a network read is not reproducible.
 *
 * THE RULE THAT MATTERS: every default used for a field nobody has answered is
 * a ZERO-DELTA REFERENCE in the engine's adjustment model. An unanswered
 * question must never flatter a pet and must never punish one. "I don't know"
 * is an answer (invariant 9), and the honest consequence of it is a wider
 * range, which the engine already produces from missing weight and illustrative
 * breeds — not a number quietly nudged in either direction. A test asserts
 * this rather than trusting the comment.
 */
import type { PetProfile } from './types'
import {
  fieldValue,
  isActivity,
  isBoolean,
  isDental,
  isDiet,
  isFiniteNumber,
  isNeuterBand,
  isOutdoor,
  isSex,
  isSpecies,
  isString,
  isStringArray,
  type Field,
  type Provenance,
  type StoredPet,
} from './stored'
import { findBreed } from './engine'

/** A field we had no answer for, and what we did about it. */
export interface Assumption {
  field: string
  /** Plain words, shown to the owner. Never states a figure we do not have. */
  note: string
}

export interface MappedPet {
  profile: PetProfile
  /**
   * What nobody has told us yet. Drives invariant 9's "we'll assume typical for
   * his breed until you know" copy, and is the input the P1 accuracy meter will
   * score against.
   */
  assumed: Assumption[]
}

/**
 * The neutral defaults. Each one is the option carrying delta 0 in the engine:
 *
 *   activity 'moderate'  → ACTIVITY_DELTAS.moderate === 0
 *   dental   'weekly'    → DENTAL_DELTAS.weekly === 0
 *   neutered false       → the neuter bonus is only added when true
 *   weightLb 0           → readBodyCondition returns 'ideal' (delta 0) AND the
 *                          engine widens the range, which is the honest signal
 *   outdoorAccess absent → the engine's own reference, 'indoor-outdoor'
 */
const NEUTRAL = {
  sex: 'female',
  neutered: false,
  weightLb: 0,
  conditionIds: [] as string[],
  activity: 'moderate',
  dental: 'weekly',
  diet: 'unsure',
} as const

/**
 * Maps a stored document to engine input.
 *
 * Returns null when the document is not usable at all — an unknown breed, a
 * missing name, an unparseable birth date. `project()` throws on an unknown
 * breed, and a pet written by an older build must not be able to take down the
 * screen (the same reasoning as `isValidPet` in App.tsx, applied to the other
 * storage backend).
 */
export function profileFromFirestore(stored: unknown): MappedPet | null {
  if (!stored || typeof stored !== 'object') return null
  const p = stored as Partial<StoredPet> & { id?: unknown }

  const id = typeof p.id === 'string' && p.id ? p.id : undefined
  const name = fieldValue(p.name, isString)?.trim()
  const species = fieldValue(p.species, isSpecies)
  const breedId = fieldValue(p.breedId, isString)
  const birthDate = fieldValue(p.birthDate, isString)

  if (!id || !name || !species || !breedId || !birthDate) return null
  if (!findBreed(breedId)) return null
  if (Number.isNaN(new Date(birthDate).getTime())) return null

  const assumed: Assumption[] = []
  const take = <T>(
    raw: unknown,
    ok: (v: unknown) => v is T,
    fallback: T,
    field: string,
    note: string,
  ): T => {
    const v = fieldValue(raw, ok)
    if (v === undefined) {
      assumed.push({ field, note })
      return fallback
    }
    return v
  }

  const profile: PetProfile = {
    id,
    name,
    species,
    breedId,
    birthDate,
    sex: take(p.sex, isSex, NEUTRAL.sex, 'sex', 'Not recorded — it does not move the projection.'),
    neutered: take(
      p.neutered,
      isBoolean,
      NEUTRAL.neutered,
      'neutered',
      "Not recorded, so we have not applied any neutering effect either way. Tell us and we'll sharpen this.",
    ),
    weightLb: take(
      p.weightLb,
      isFiniteNumber,
      NEUTRAL.weightLb,
      'weightLb',
      "No weight yet, so the range stays deliberately wide. It's the input that moves the projection most.",
    ),
    conditionIds: take(
      p.conditionIds,
      isStringArray,
      NEUTRAL.conditionIds,
      'conditionIds',
      "Nothing declared. We're reading this as nothing known rather than nothing there.",
    ),
    activity: take(
      p.activity,
      isActivity,
      NEUTRAL.activity,
      'activity',
      "Assuming a typical day until you tell us otherwise — that's the middle setting, not a guess in either direction.",
    ),
    dental: take(
      p.dental,
      isDental,
      NEUTRAL.dental,
      'dental',
      'Assuming the middle of the range, which moves the projection by nothing.',
    ),
    diet: take(p.diet, isDiet, NEUTRAL.diet, 'diet', 'Not recorded.'),
  }

  // Optional engine fields: absent means absent. The engine already treats a
  // missing outdoorAccess as its reference and a missing neuterAgeBand as "not
  // asked", so there is nothing to default and nothing to assume.
  const neuterAgeBand = fieldValue(p.neuterAgeBand, isNeuterBand)
  if (neuterAgeBand) profile.neuterAgeBand = neuterAgeBand
  const outdoorAccess = fieldValue(p.outdoorAccess, isOutdoor)
  if (outdoorAccess) profile.outdoorAccess = outdoorAccess
  else if (species === 'cat') {
    assumed.push({
      field: 'outdoorAccess',
      note: "Not recorded. We're treating him as a cat who comes and goes, which is our reference point rather than a penalty.",
    })
  }
  const headline = fieldValue(p.headline, isString)
  if (headline) profile.headline = headline

  return { profile, assumed }
}

/**
 * The other direction: a pet the owner built in the pre-account session becomes
 * a stored document. Everything they typed is `owner_declared` — they declared
 * it — and nothing is invented to fill a gap, so a field they skipped stays
 * absent rather than being written as a default. Writing a default here would
 * launder an assumption into a fact, and the provenance would say the owner
 * said it.
 */
export function storedFromProfile(
  profile: PetProfile,
  ctx: { householdId: string; uid: string; now: Date; importedFrom?: 'localStorage' },
): StoredPet {
  const at = ctx.now.toISOString()
  const f = <T>(value: T, provenance: Provenance = 'owner_declared'): Field<T> => ({
    value,
    provenance,
    updatedAt: at,
    updatedBy: ctx.uid,
  })

  const out: StoredPet = {
    id: profile.id,
    householdId: ctx.householdId,
    createdAt: at,
    createdBy: ctx.uid,
    name: f(profile.name),
    species: f(profile.species),
    breedId: f(profile.breedId),
    birthDate: f(profile.birthDate),
    sex: f(profile.sex),
    neutered: f(profile.neutered),
    conditionIds: f(profile.conditionIds ?? []),
    activity: f(profile.activity),
    dental: f(profile.dental),
    diet: f(profile.diet),
  }

  if (ctx.importedFrom) out.importedFrom = ctx.importedFrom
  // Only write what was actually answered. weightLb of 0 means "not given".
  if (Number.isFinite(profile.weightLb) && profile.weightLb > 0) {
    out.weightLb = f(profile.weightLb)
  }
  if (profile.neuterAgeBand) out.neuterAgeBand = f(profile.neuterAgeBand)
  if (profile.outdoorAccess) out.outdoorAccess = f(profile.outdoorAccess)
  if (profile.headline) out.headline = f(profile.headline)

  return out
}
