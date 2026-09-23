/**
 * How sharp a pet's plan is, and what would sharpen it most.
 *
 * SPEC §4.2: "Plan-accuracy meter — e.g. 'Max's plan: 68% sharp — add his body
 * condition to reach 80%.' Deterministic scoring function in the engine package
 * with tests; surfaced on Home until >90%."
 *
 * Pure, like everything else in this package. No IO, no clock, no randomness.
 *
 * WHAT THE NUMBER MEANS, AND WHAT IT DOES NOT
 * It measures how much of what would sharpen THIS pet's projection we actually
 * know — not engagement, not profile completeness, and not how well anyone is
 * caring for their pet. A field is worth points in proportion to how much it
 * moves or narrows the projection, so the meter and the engine cannot disagree:
 * anything that earns points here demonstrably changes something there.
 *
 * Three consequences worth understanding before reading the weights:
 *
 *  1. A photo is worth nothing. It is the most satisfying thing an owner can
 *     add and it sharpens the projection not at all. Paying points for it would
 *     make the meter a measure of engagement wearing a lab coat.
 *  2. Species-specific fields only count for that species. Outdoor access is a
 *     large part of a cat's picture and irrelevant to a dog, so a dog is never
 *     marked down for a question nobody asked.
 *  3. YOU CANNOT REACH 100% ON A MIXED BREED, and that is the honest answer.
 *     The breed baseline is a real input; if it is a size-class fallback or an
 *     illustrative figure, we genuinely know less about this animal and the
 *     number says so rather than flattering. The ceiling is explained in the UI.
 */
import type { Breed, PetProfile } from '../data/types'
import { findBreed } from '../data/engine'

export interface AccuracyField {
  /** Matches the PetProfile key, so the UI can route to the right control. */
  field: string
  /** What to call it on screen. */
  label: string
  /** Why answering helps THIS pet — never a generic "complete your profile". */
  benefit: string
  /** Points it is worth, out of 100. */
  points: number
  answered: boolean
}

export interface PlanAccuracy {
  /** 0–100, rounded. */
  score: number
  /** The most valuable unanswered field, or null when everything is answered. */
  nextBest: AccuracyField | null
  /** What the score would become if `nextBest` were answered. */
  scoreWithNextBest: number
  /** Every field considered, answered or not, in descending value. */
  fields: AccuracyField[]
  /**
   * The highest score this pet can reach, and why it is not 100. Null when the
   * ceiling is 100 — i.e. the breed baseline is a published breed-level figure.
   */
  ceiling: { max: number; reason: string } | null
  /** SPEC: surfaced on Home until above 90. */
  showOnHome: boolean
}

/**
 * What Tier 0 is worth on its own.
 *
 * A pet with only species, breed, name, birthday and sex is not a 0% plan. The
 * breed baseline and the age ARE the projection — every Tier-1 field adjusts a
 * number those two produced. Scoring them at nothing would tell someone their
 * reveal was worthless at the exact moment they were most impressed by it, and
 * would be false besides.
 *
 * So Tier 0 carries 40 and the Tier-1 fields share the remaining 60. That also
 * puts SPEC §4.2's own example — "68% sharp" — where it naturally falls,
 * partway through Tier 1.
 */
const TIER0_POINTS = 40
const TIER1_POINTS = 60

/**
 * What each Tier-1 field is worth, RELATIVE to the others.
 *
 * Ordered by how much it actually changes the projection, not by how easy it is
 * to ask. Body condition is the largest single lever in the engine and the
 * largest here; diet moves nothing in `project()` and is worth the least.
 */
const WEIGHTS = {
  weightLb: 26,
  conditionIds: 18,
  neutered: 12,
  activity: 11,
  dental: 11,
  /** Cats only. A large part of the feline picture, absent from the canine one. */
  outdoorAccess: 14,
  /** Dogs only, and only the large ones — it is framing, not a lifespan input. */
  neuterAgeBand: 6,
  diet: 4,
} as const

const BENEFIT: Record<string, string> = {
  weightLb:
    'Body condition moves the projection more than anything else you can tell us.',
  conditionIds:
    "Anything already diagnosed changes the plan from watching for it to managing it.",
  neutered: 'Neutering is consistently associated with longer life across large datasets.',
  activity: 'How much they move is part of the healthy-years picture.',
  dental: 'Dental routine is a small but real part of the picture.',
  outdoorAccess:
    'Whether a cat goes out is the biggest thing we can still ask about a cat.',
  neuterAgeBand:
    'In a dog this size, the timing tells us what to watch for in their joints.',
  diet: 'Fills in how they eat day to day.',
}

const LABEL: Record<string, string> = {
  weightLb: 'body condition',
  conditionIds: 'anything diagnosed',
  neutered: 'neutered or spayed',
  activity: 'activity level',
  dental: 'dental routine',
  outdoorAccess: 'indoor or outdoor',
  neuterAgeBand: 'age at neutering',
  diet: 'how they eat',
}

/**
 * Whether a field counts as answered.
 *
 * `conditionIds` is the interesting one: an empty array means "the owner looked
 * at the list and chose none", which is a real answer and invariant 9's
 * "I don't know is always an answer" in its most common form. But the engine
 * also defaults a missing field to `[]`, so the two are indistinguishable on
 * the profile alone. We therefore treat it as answered only when the owner has
 * been through onboarding — which is what `conditionsReviewed` records.
 */
function isAnswered(profile: PetProfile, field: string): boolean {
  switch (field) {
    case 'weightLb':
      return Number.isFinite(profile.weightLb) && profile.weightLb > 0
    case 'conditionIds':
      return (
        (profile.conditionIds?.length ?? 0) > 0 || profile.conditionsReviewed === true
      )
    case 'neutered':
      return typeof profile.neutered === 'boolean'
    case 'outdoorAccess':
      return !!profile.outdoorAccess
    case 'neuterAgeBand':
      return !!profile.neuterAgeBand && profile.neuterAgeBand !== 'unsure'
    case 'activity':
    case 'dental':
    case 'diet':
      return !!profile[field as 'activity' | 'dental' | 'diet']
    default:
      return false
  }
}

/** Hart 2020's ≥20 kg group, read off the breed's typical adult size. */
const JOINT_RISK_LB = 45
function asksNeuterAge(breed: Breed, profile: PetProfile): boolean {
  if (breed.species !== 'dog' || !profile.neutered) return false
  return (breed.weight.low + breed.weight.high) / 2 >= JOINT_RISK_LB
}

/**
 * The ceiling, and why.
 *
 * A mixed breed or an illustrative baseline means the starting point is a
 * size-class figure rather than a figure for this animal's breed. No amount of
 * answering fixes that, so the meter must not imply it can.
 */
function ceilingFor(breed: Breed): PlanAccuracy['ceiling'] {
  if (breed.isMixed) {
    return {
      max: 85,
      reason:
        "We're working from a size-class average rather than a breed figure, so this tops out at 85%. That is the honest limit of what we know, not something left to fill in.",
    }
  }
  if (breed.confidence === 'illustrative') {
    return {
      max: 88,
      reason: `No breed-level figure has been published for the ${breed.name}, so the starting point is a size-class average. This tops out at 88% until one exists.`,
    }
  }
  if (breed.confidence === 'derived') {
    return {
      max: 94,
      reason: `The ${breed.name} figure measures something that does not transfer exactly to a pet at home, so this tops out at 94%.`,
    }
  }
  return null
}

export function planAccuracy(profile: PetProfile): PlanAccuracy {
  const breed = findBreed(profile.breedId)
  if (!breed) {
    return {
      score: 0,
      nextBest: null,
      scoreWithNextBest: 0,
      fields: [],
      ceiling: null,
      showOnHome: false,
    }
  }

  const applicable: string[] = ['weightLb', 'conditionIds', 'neutered', 'activity', 'dental', 'diet']
  if (breed.species === 'cat') applicable.push('outdoorAccess')
  if (asksNeuterAge(breed, profile)) applicable.push('neuterAgeBand')

  const fields: AccuracyField[] = applicable
    .map((field) => ({
      field,
      label: LABEL[field],
      benefit: BENEFIT[field],
      points: WEIGHTS[field as keyof typeof WEIGHTS],
      answered: isAnswered(profile, field),
    }))
    .sort((a, b) => b.points - a.points)

  // Normalised against what is applicable to THIS pet, so a dog is never marked
  // down for the cat question and a small dog is never marked down for a
  // question Hart's finding does not reach.
  const total = fields.reduce((s, f) => s + f.points, 0)
  const earned = fields.filter((f) => f.answered).reduce((s, f) => s + f.points, 0)
  const raw =
    total === 0 ? 100 : TIER0_POINTS + (earned / total) * TIER1_POINTS

  const ceiling = ceilingFor(breed)
  const cap = ceiling?.max ?? 100
  const score = Math.round(Math.min(raw, cap))

  const nextBest = fields.find((f) => !f.answered) ?? null
  const withNext = nextBest
    ? Math.round(
        Math.min(TIER0_POINTS + ((earned + nextBest.points) / total) * TIER1_POINTS, cap),
      )
    : score

  return {
    score,
    nextBest,
    scoreWithNextBest: withNext,
    fields,
    ceiling,
    showOnHome: score <= 90,
  }
}

/**
 * The one-line nudge. "Max's plan: 68% sharp — add his body condition to reach
 * 80%." Kept here rather than in a component so the copy is testable and there
 * is one place it can drift from.
 */
export function accuracyLine(name: string, a: PlanAccuracy): string {
  if (!a.nextBest) {
    return a.ceiling
      ? `${name}'s plan is ${a.score}% sharp — as sharp as it goes for this breed.`
      : `${name}'s plan is ${a.score}% sharp. You've told us everything that moves it.`
  }
  return `${name}'s plan: ${a.score}% sharp — add ${a.nextBest.label} to reach ${a.scoreWithNextBest}%.`
}
