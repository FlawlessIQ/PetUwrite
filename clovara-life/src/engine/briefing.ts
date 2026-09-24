/**
 * The morning briefing (SPEC-HORIZON §1.2).
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * THE RULE: NEVER INVENT A REASON.
 *
 * If the only true thing today is "nothing needs attention", it says that and
 * stops. A briefing padded to feel valuable trains people to stop reading it,
 * and the cost of that is paid on the day it matters. Every line below comes
 * from something already known — a dose logged or not, a window opening, a
 * review falling due — and there is no generic tip anywhere in this file.
 *
 * IT IS ONE MORE CONSUMER OF THE PROJECTION (invariant 7). It computes nothing
 * of its own: the vaccination window comes from `vaccines.ts`, the review from
 * `review.ts`, the doses from `meds.ts`. A briefing that forked its own truth
 * would drift from the surfaces it summarises.
 *
 * WEATHER SITS BEHIND A SEAM WITH NOTHING IN IT. Heat and pollen are the two
 * environmental facts worth a line, and both need a provider nobody has chosen.
 * The null provider returns nothing and the briefing simply has one fewer
 * thing to say, which is the correct behaviour rather than a gap.
 * ═══════════════════════════════════════════════════════════════════════════
 *
 * Pure; clock injected.
 */
import type { PetProfile, Projection } from '../data/types'
import { isRemembered } from './remember'
import { reviewDue } from './review'
import { vaccineState } from './vaccines'
import { medState, type Medication } from './meds'
import { lumpState, type Lump } from './lumps'

export interface BriefingItem {
  id: string
  /** The line itself, already true. */
  text: string
  /** Where it came from, so nothing is unattributable. */
  from: 'medication' | 'vaccination' | 'review' | 'lump-diary' | 'stage' | 'environment'
  /** Needs doing today rather than merely worth knowing. */
  actionable: boolean
}

export interface Briefing {
  /** Null when there is nothing true to say — which is a valid morning. */
  items: BriefingItem[]
  /** Shown when items is empty. Never padding. */
  nothingToSay: string | null
  petName: string
}

// ── The environment seam ───────────────────────────────────────────────────

export interface EnvironmentReading {
  /** Celsius. */
  highToday: number | null
  /** 'low' | 'moderate' | 'high', or null when unknown. */
  pollen: 'low' | 'moderate' | 'high' | null
}

export interface EnvironmentProvider {
  id: string
  available: boolean
  read(at: { lat: number; lng: number }, now: Date): Promise<EnvironmentReading>
}

/**
 * Nothing is chosen. Returns nothing, and the briefing has one fewer line.
 *
 * Not an error state: a briefing without a weather line is a complete
 * briefing, and inventing "it might be warm today" would be exactly the
 * padding this file exists to refuse.
 */
export const NULL_ENVIRONMENT: EnvironmentProvider = {
  id: 'none',
  available: false,
  async read() {
    return { highToday: null, pollen: null }
  },
}

/** Above this, heat is worth a line for a dog. */
export const HOT_C = 24

// ── The briefing ───────────────────────────────────────────────────────────

export function buildBriefing(
  pet: PetProfile,
  projection: Projection,
  now: Date,
  environment?: EnvironmentReading,
): Briefing {
  const items: BriefingItem[] = []

  // Nothing at all, ever, once they have died.
  if (isRemembered(pet)) {
    return { items: [], nothingToSay: null, petName: pet.name }
  }

  // ── Medication, which is the only thing that is genuinely today ─────────
  for (const raw of (pet.medications ?? []) as Medication[]) {
    const s = medState(raw, now)
    if (s.perDay > 0 && !s.doneToday) {
      items.push({
        id: `med-${raw.id}`,
        text:
          s.givenToday === 0
            ? `${raw.name}: ${raw.amount}, ${s.perDay} today.`
            : `${raw.name}: ${s.perDay - s.givenToday} more today.`,
        from: 'medication',
        actionable: true,
      })
    }
    if (s.runningOut) {
      items.push({
        id: `med-out-${raw.id}`,
        text: `${raw.name} runs out in about ${s.daysLeft} day${s.daysLeft === 1 ? '' : 's'}, by your count.`,
        from: 'medication',
        actionable: true,
      })
    }
  }

  // ── Vaccination, only when the window is actually open ──────────────────
  const vax = vaccineState(pet, now)
  for (const due of vax.dueNow) {
    items.push({
      id: `vax-${due.dose.id}`,
      text: `Around now is when ${due.vaccine.label} is usually given.`,
      from: 'vaccination',
      actionable: true,
    })
  }

  // ── The annual review ──────────────────────────────────────────────────
  if (reviewDue(pet, now)) {
    items.push({
      id: 'review',
      text: `It has been a year — five questions when you have a minute.`,
      from: 'review',
      actionable: false,
    })
  }

  // ── The lump diary, only where one is already being tracked ────────────
  for (const lump of (pet.lumps ?? []) as Lump[]) {
    const s = lumpState(lump, now)
    if (s.photoCount > 0 && s.daysSinceLast !== null && s.daysSinceLast >= 28) {
      items.push({
        id: `lump-${lump.id}`,
        text: `${lump.location}: last photographed ${s.daysSinceLast} days ago.`,
        from: 'lump-diary',
        actionable: false,
      })
    }
  }

  // ── Environment, when a provider has actually said something ───────────
  if (environment?.highToday !== null && environment?.highToday !== undefined) {
    if (environment.highToday >= HOT_C && pet.species === 'dog') {
      items.push({
        id: 'heat',
        text: `${environment.highToday}° today — walk early, and check the pavement with your hand first.`,
        from: 'environment',
        actionable: true,
      })
    }
  }
  if (environment?.pollen === 'high') {
    items.push({
      id: 'pollen',
      text: 'Pollen is high today.',
      from: 'environment',
      actionable: false,
    })
  }

  // ── The stage, only when nothing else is true ──────────────────────────
  // Deliberately last and deliberately conditional: it is context rather than
  // news, and a briefing that always contains it is a briefing that always
  // contains something, which is the habit this file refuses to build.
  if (items.length === 0) {
    return {
      items: [],
      nothingToSay: `Nothing needs doing for ${pet.name} today. ${projection.currentStage.label} stage, and nothing on our list has come round.`,
      petName: pet.name,
    }
  }

  return { items, nothingToSay: null, petName: pet.name }
}

/**
 * Delivery (SPEC-HORIZON §1.2's open decision).
 *
 * Off. A daily email is a different consent from a monthly one, and it is
 * Conor's call rather than an engineering default. The briefing renders in the
 * app today; when the decision is made, this becomes true and the P0 pluggable
 * sender already exists.
 */
export const BRIEFING_EMAIL_ENABLED = false
