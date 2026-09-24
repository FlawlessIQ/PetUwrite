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
  isBodyScore,
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

/** Untrusted like everything else out of Firestore — a half-written photo
 *  record must not put a broken image on every screen. */
const isPhoto = (v: unknown): v is PetProfile['photo'] => {
  if (!v || typeof v !== 'object') return false
  const p = v as Record<string, unknown>
  return (
    typeof p.avatarUrl === 'string' &&
    p.avatarUrl.startsWith('http') &&
    typeof p.avatarPath === 'string' &&
    typeof p.fullPath === 'string'
  )
}

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
  weightLb: 0,
  conditionIds: [] as string[],
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
/** A stored healthy-years range. Rejected wholesale if either end is missing. */
function isRange(v: unknown): v is { low: number; high: number } {
  if (!v || typeof v !== 'object') return false
  const r = v as Record<string, unknown>
  return Number.isFinite(r.low) && Number.isFinite(r.high)
}

/** Recorded doses. Anything without both fields as strings is dropped whole. */
function isDoseArray(v: unknown): v is { doseId: string; givenOn: string }[] {
  return (
    Array.isArray(v) &&
    v.every(
      (x) =>
        !!x &&
        typeof x === 'object' &&
        typeof (x as Record<string, unknown>).doseId === 'string' &&
        typeof (x as Record<string, unknown>).givenOn === 'string',
    )
  )
}

/** The sitter card's free-text fields. Anything non-string is dropped. */
function isStringRecord(v: unknown): v is Record<string, string> {
  return (
    !!v && typeof v === 'object' && !Array.isArray(v) &&
    Object.values(v as Record<string, unknown>).every((x) => typeof x === 'string')
  )
}

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
  }

  const optional = <T>(
    raw: unknown,
    ok: (v: unknown) => v is T,
    key: 'activity' | 'dental' | 'diet',
    note: string,
  ) => {
    const v = fieldValue(raw, ok)
    if (v === undefined) assumed.push({ field: key, note })
    else Object.assign(profile, { [key]: v })
  }
  optional(
    p.activity,
    isActivity,
    'activity',
    "Assuming a typical day until you tell us otherwise — that's the middle setting, not a guess in either direction.",
  )
  optional(
    p.dental,
    isDental,
    'dental',
    'Assuming the middle of the range, which moves the projection by nothing.',
  )
  optional(p.diet, isDiet, 'diet', 'Not recorded.')

  // `neutered` is left ABSENT when nobody has said. The engine adds its bonus
  // only when the field is true, so absent costs nothing — but writing `false`
  // would record "intact" as though someone had told us, which is a different
  // claim and one the accuracy meter would then stop asking about.
  const neutered = fieldValue(p.neutered, isBoolean)
  if (neutered === undefined) {
    assumed.push({
      field: 'neutered',
      note: "Not recorded, so we have not applied any neutering effect either way. Tell us and we'll sharpen this.",
    })
  } else {
    profile.neutered = neutered
  }

  const reviewed = fieldValue(p.conditionsReviewed, isBoolean)
  if (reviewed !== undefined) profile.conditionsReviewed = reviewed
  const knownSince = fieldValue(p.knownSince, isString)
  if (knownSince !== undefined) profile.knownSince = knownSince
  const lastReviewed = fieldValue(p.lastReviewedAt, isString)
  if (lastReviewed !== undefined) profile.lastReviewedAt = lastReviewed
  const lastRange = fieldValue(p.lastReviewedRange, isRange)
  if (lastRange !== undefined) profile.lastReviewedRange = lastRange
  const stamps = fieldValue(p.socialStamps, isStringArray)
  if (stamps !== undefined) profile.socialStamps = stamps
  const shots = fieldValue(p.vaccineRecords, isDoseArray)
  if (shots !== undefined) profile.vaccineRecords = shots
  const notes = fieldValue(p.careNotes, isStringRecord)
  if (notes !== undefined) profile.careNotes = notes
  const died = fieldValue(p.diedOn, isString)
  if (died !== undefined) profile.diedOn = died
  const lumps = fieldValue(p.lumps, Array.isArray)
  if (lumps !== undefined) profile.lumps = lumps as PetProfile['lumps']
  const approx = fieldValue(p.birthDateApprox, isBoolean)
  if (approx !== undefined) profile.birthDateApprox = approx
  const bcs = fieldValue(p.bodyConditionScore, isBodyScore)
  if (bcs !== undefined) profile.bodyConditionScore = bcs

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
  const photo = fieldValue(p.photo, isPhoto)
  if (photo) profile.photo = photo

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
    conditionIds: f(profile.conditionIds ?? []),
  }
  if (profile.activity) out.activity = f(profile.activity)
  if (profile.dental) out.dental = f(profile.dental)
  if (profile.diet) out.diet = f(profile.diet)

  if (ctx.importedFrom) out.importedFrom = ctx.importedFrom
  if (typeof profile.neutered === 'boolean') out.neutered = f(profile.neutered)
  if (profile.birthDateApprox) out.birthDateApprox = f(profile.birthDateApprox)
  if (profile.bodyConditionScore) out.bodyConditionScore = f(profile.bodyConditionScore)
  if (profile.photo) out.photo = f(profile.photo)
  if (profile.conditionsReviewed) out.conditionsReviewed = f(profile.conditionsReviewed)
  if (profile.knownSince) out.knownSince = f(profile.knownSince)
  if (profile.lastReviewedAt) out.lastReviewedAt = f(profile.lastReviewedAt)
  if (profile.lastReviewedRange) out.lastReviewedRange = f(profile.lastReviewedRange)
  if (profile.socialStamps?.length) out.socialStamps = f(profile.socialStamps)
  if (profile.vaccineRecords?.length) out.vaccineRecords = f(profile.vaccineRecords)
  if (profile.careNotes && Object.keys(profile.careNotes).length) out.careNotes = f(profile.careNotes)
  if (profile.lumps?.length) out.lumps = f(profile.lumps)
  if (profile.diedOn) out.diedOn = f(profile.diedOn)
  // Only write what was actually answered. weightLb of 0 means "not given".
  if (Number.isFinite(profile.weightLb) && profile.weightLb > 0) {
    out.weightLb = f(profile.weightLb)
  }
  if (profile.neuterAgeBand) out.neuterAgeBand = f(profile.neuterAgeBand)
  if (profile.outdoorAccess) out.outdoorAccess = f(profile.outdoorAccess)
  if (profile.headline) out.headline = f(profile.headline)

  return out
}
