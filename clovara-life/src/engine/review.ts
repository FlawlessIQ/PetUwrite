/**
 * The annual re-projection (SPEC §4.3): "anything change this year?"
 *
 * Two jobs in one screen. It is the yearly data refresh — the only structured
 * chance to correct facts that drift — and it is the moment the projection is
 * honestly restated a year on.
 *
 * WHAT THIS IS NOT: a new place to ask new questions. Every field it touches is
 * already placed somewhere by the ask registry; this re-confirms answers rather
 * than collecting them, and a test asserts it can never become a back door for
 * a question nobody registered.
 *
 * Pure. No IO, no clock of its own — `now` is injected, as everywhere else in
 * the engine.
 */
import type { PetProfile, Species } from '../data/types'
import { isRemembered } from './remember'

const YEAR = 365.25 * 86_400_000

export interface ReviewItem {
  /** The PetProfile field this re-confirms. */
  field: string
  /** What we currently hold, in the owner's words. */
  current: string
  /** The question, phrased as a check rather than as a fresh ask. */
  prompt: string
  /**
   * Why we are asking again. Never "keep your profile up to date" — the reason
   * has to be about the animal or it should not be on the screen.
   */
  because: string
  species?: Species
  /**
   * True when there is nothing on file to re-confirm. "Still true" cannot
   * apply to a question nobody put (UAT run 1, D7), so the review offers to
   * answer it instead.
   */
  neverAsked: boolean
}

/** The most recent birthday on or before `now`, as a timestamp. */
export function lastBirthday(birthDate: string, now: Date): number | null {
  const born = new Date(birthDate)
  if (Number.isNaN(born.getTime())) return null
  const candidate = new Date(now)
  candidate.setUTCMonth(born.getUTCMonth(), born.getUTCDate())
  candidate.setUTCHours(0, 0, 0, 0)
  if (candidate.getTime() > now.getTime()) candidate.setUTCFullYear(candidate.getUTCFullYear() - 1)
  return candidate.getTime()
}

/**
 * Whether a review is due.
 *
 * The journey map calls this "every birthday her plan is re-drawn", and the
 * birthday is the anchor for a reason: anniversary-of-the-last-review drifts
 * later every year someone answers a fortnight late, until the yearly ritual
 * lands in a different season than it started.
 *
 * Two conditions, both necessary:
 *
 *  1. We have known this pet for at least a year. A nine-year-old rescue
 *     adopted six days before their birthday should not be met with "anything
 *     change this year?" — we have no year to ask about.
 *  2. A birthday has passed since the last review.
 */
export function reviewDue(
  pet: { lastReviewedAt?: string; knownSince?: string; birthDate: string; diedOn?: string },
  now: Date,
): boolean {
  // Without knowing when we met them we cannot tell a long-standing pet from
  // one added this morning, and nothing is due. The safe direction.
  // Silent once a pet has died (SPEC-HORIZON §2.5). Enforced here rather
  // than in each surface, so a component that forgets to check renders nothing.
  if (isRemembered(pet)) return false
  if (!pet.knownSince) return false
  const since = Date.parse(pet.knownSince)
  if (!Number.isFinite(since)) return false
  if (now.getTime() - since < YEAR) return false

  const birthday = lastBirthday(pet.birthDate, now)
  if (birthday === null) return false

  if (!pet.lastReviewedAt) return true
  const reviewed = Date.parse(pet.lastReviewedAt)
  if (!Number.isFinite(reviewed)) return true
  return reviewed < birthday
}

/**
 * Days until the next review — the next birthday, once the pet is old enough
 * with us to have one asked about. Null when we cannot say.
 */
export function daysUntilReview(
  pet: { lastReviewedAt?: string; knownSince?: string; birthDate: string },
  now: Date,
): number | null {
  if (!pet.knownSince || !Number.isFinite(Date.parse(pet.knownSince))) return null
  if (reviewDue(pet, now)) return 0
  const birthday = lastBirthday(pet.birthDate, now)
  if (birthday === null) return null
  const next = new Date(birthday)
  next.setUTCFullYear(next.getUTCFullYear() + 1)
  const byBirthday = Math.ceil((next.getTime() - now.getTime()) / 86_400_000)
  // A pet we have not yet known a year waits for that, not just the birthday.
  const byTenure = Math.ceil((Date.parse(pet.knownSince) + YEAR - now.getTime()) / 86_400_000)
  return Math.max(0, byBirthday, byTenure)
}

const BODY_CONDITION_WORDS: Record<number, string> = {
  1: 'bony',
  2: 'thin',
  3: 'ideal',
  4: 'plump',
  5: 'heavy',
}

/**
 * Species-neutral on purpose. Sharpen's own hints talk about walks, which is
 * fine where a dog owner is answering a dog question — here the same string has
 * to read back to the owner of a cat, and "short or irregular walks" describes
 * an animal nobody walks.
 */
const ACTIVITY_WORDS: Record<string, string> = {
  low: 'not very active',
  moderate: 'active most days',
  high: 'very active',
}

const DENTAL_WORDS: Record<string, string> = {
  daily: 'teeth cleaned daily',
  weekly: 'teeth cleaned weekly',
  rarely: 'teeth cleaned rarely',
}

const OUTDOOR_WORDS: Record<string, string> = {
  indoor: 'indoors only',
  'indoor-outdoor': 'in and out',
  outdoor: 'mostly outdoors',
}

/**
 * What to put in front of someone, in the order it matters.
 *
 * Only things that genuinely change in a year. Breed, birthday and sex are not
 * here: re-asking a fact that cannot have changed is how a "review" becomes a
 * form. Neutering is here only while the answer is still no, because that is
 * the one direction it moves.
 */
export function reviewItems(pet: PetProfile): ReviewItem[] {
  const items: Omit<ReviewItem, 'neverAsked'>[] = []

  items.push({
    field: 'weightLb',
    current:
      pet.bodyConditionScore !== undefined
        ? `${pet.name} was ${BODY_CONDITION_WORDS[pet.bodyConditionScore]}`
        : pet.weightLb > 0
          ? `${pet.weightLb} lb`
          : 'we have never been told',
    prompt: 'Has their shape changed?',
    because: 'Body condition moves the projection more than anything else, and it is what drifts.',
  })

  items.push({
    field: 'conditionIds',
    current:
      pet.conditionIds.length === 0
        ? pet.conditionsReviewed
          ? 'nothing diagnosed'
          : 'we have never asked'
        : `${pet.conditionIds.length} noted`,
    prompt: 'Anything diagnosed since last year?',
    because: 'A new diagnosis changes the plan from watching for something to managing it.',
  })

  if (pet.neutered !== true) {
    items.push({
      field: 'neutered',
      current: pet.neutered === false ? 'not neutered' : 'we have never asked',
      prompt: 'Neutered or spayed since?',
      because: 'It is the one answer here that only moves in one direction.',
    })
  }

  if (pet.species === 'cat') {
    items.push({
      field: 'outdoorAccess',
      current: pet.outdoorAccess ? OUTDOOR_WORDS[pet.outdoorAccess] : 'we have never asked',
      prompt: 'Do they still get out as much?',
      because: 'A cat who has stopped going out, or started, is a different animal to us.',
      species: 'cat',
    })
  }

  items.push({
    field: 'activity',
    current: pet.activity ? ACTIVITY_WORDS[pet.activity] : 'we have never asked',
    prompt: 'Are they moving as much?',
    because: 'Slowing down is often the first thing an owner notices and the last thing they mention.',
  })

  items.push({
    field: 'dental',
    current: pet.dental ? DENTAL_WORDS[pet.dental] : 'we have never asked',
    prompt: 'Has the teeth routine changed?',
    because: 'It is small, it is real, and it is the one people quietly stop doing.',
  })

  const onFile: Record<string, boolean> = {
    weightLb: pet.bodyConditionScore !== undefined || pet.weightLb > 0,
    conditionIds: pet.conditionIds.length > 0 || pet.conditionsReviewed === true,
    neutered: pet.neutered !== undefined,
    outdoorAccess: !!pet.outdoorAccess,
    activity: !!pet.activity,
    dental: !!pet.dental,
  }
  return items.map((i) => {
    const neverAsked = !(onFile[i.field] ?? true)
    // A re-check needs something to re-check. "Anything diagnosed since last
    // year?" beside "Answer it", for a question never asked, read as if it had
    // been (UAT run 2, N2).
    return { ...i, neverAsked, prompt: neverAsked ? (FIRST_PROMPT[i.field] ?? i.prompt) : i.prompt }
  })
}

/** How each question reads when it is being asked for the first time. */
const FIRST_PROMPT: Record<string, string> = {
  weightLb: 'What shape are they in?',
  conditionIds: 'Anything diagnosed?',
  neutered: 'Neutered or spayed?',
  outdoorAccess: 'Do they get outside?',
  activity: 'How much do they move on a normal day?',
  dental: 'Are their teeth cleaned at home?',
}

export interface ProjectionShift {
  /** Change in the low end of the healthy-years range, rounded to 0.1. */
  low: number
  high: number
  /** True when nothing moved at all. */
  unchanged: boolean
}

/**
 * The difference between two projections, for the diff-style review SPEC asks
 * for.
 *
 * Deliberately just arithmetic. Whether a fall is framed as bad news is a
 * question for the copy, and the copy is where someone can see it and argue
 * with it, rather than buried in a helper that decides tone.
 */
export function projectionShift(
  before: { low: number; high: number },
  after: { low: number; high: number },
): ProjectionShift {
  const round = (n: number) => Math.round(n * 10) / 10
  const low = round(after.low - before.low)
  const high = round(after.high - before.high)
  return { low, high, unchanged: low === 0 && high === 0 }
}
