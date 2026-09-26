/**
 * The attach flow (SPEC §5): the pre-priced offer, and the screen of truth.
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * THE RATING ADAPTER IS THE POINT OF THIS FILE.
 *
 * SPEC §5: "build the UX now against a mock rating/binding adapter with the
 * same interface the Accelerant-program integration will use; real binding is
 * gated on the carrier program going live and is NOT this phase's dependency."
 *
 * So `RatingAdapter` is the contract, `MockRatingAdapter` implements it from
 * the illustrative tables already in the repo, and every surface goes through
 * it. When the carrier program lands, a real adapter implements the same three
 * calls and no screen changes.
 *
 * `quote()` returns `illustrative: true` from the mock, and the UI is required
 * to label anything illustrative (invariant 2). A real adapter returning filed
 * rates sets it false and the amber box disappears on its own.
 * ═══════════════════════════════════════════════════════════════════════════
 *
 * Pure; clock injected.
 */
import { PLAN_TIERS, RIDER_PRICE, type PlanTier } from '../data/coverage'
import { WAITING_PERIODS } from '../data/attach'
import { KNOWN_CONDITIONS } from '../data/conditions'
import type { PetProfile, Projection } from '../data/types'
import { buildCoverage } from './platform'

export interface QuoteOptions {
  tierId: string
  /** Include the non-insurance wellness rider. */
  rider: boolean
}

export interface Quote {
  tier: PlanTier
  monthlyPremium: number
  riderPrice: number
  totalMonthly: number
  /** Every factor, shown. */
  breakdown: { label: string; value: string; note: string }[]
  /**
   * True until rates are filed. The UI must label anything illustrative
   * (invariant 2), and a real adapter setting this false removes the label
   * without anybody editing a component.
   */
  illustrative: boolean
  adapterId: string
}

export interface BindRequest {
  petId: string
  tierId: string
  rider: boolean
  effectiveDate: string
}

export interface BindResult {
  ok: boolean
  policyNumber: string | null
  effectiveDate: string
  /** Set when binding is not possible yet. */
  unavailableReason?: string
}

export interface RatingAdapter {
  id: string
  /** False until the carrier program is live. */
  canBind: boolean
  quote(pet: PetProfile, projection: Projection, opts: QuoteOptions): Quote
  /** The smart default configuration, computed from the plan. No form. */
  smartDefault(pet: PetProfile, projection: Projection): QuoteOptions
  bind(req: BindRequest): Promise<BindResult>
}

/**
 * Reads the illustrative tables already in the repo, through the existing
 * `buildCoverage` so there is exactly one place premiums are computed.
 */
export const MockRatingAdapter: RatingAdapter = {
  id: 'mock',
  canBind: false,

  quote(pet, projection, opts) {
    const view = buildCoverage(pet, projection, opts.tierId)
    // Unreachable through the app — App routes a remembered pet's #/protect to
    // a quiet screen — and a throw rather than a price if that ever breaks.
    if (!view) throw new Error('No cover is priced for a pet who has died')
    const riderPrice = opts.rider ? RIDER_PRICE[pet.species] : 0
    return {
      tier: view.tier,
      monthlyPremium: view.monthlyPremium,
      riderPrice,
      totalMonthly: Math.round((view.monthlyPremium + riderPrice) * 100) / 100,
      breakdown: view.breakdown,
      illustrative: true,
      adapterId: 'mock',
    }
  },

  /**
   * SPEC §5: "one smart default configuration computed from the Plan (no
   * form)". The default is Complete, because the tier nobody regrets is the one
   * that pays out; the rider defaults ON only for animals young enough for the
   * routine care it covers to still be ahead of them.
   */
  smartDefault(_pet, projection) {
    return {
      tierId: PLAN_TIERS.find((t) => t.id === 'complete')?.id ?? PLAN_TIERS[0].id,
      rider: projection.ageYears < 8,
    }
  },

  async bind() {
    return {
      ok: false,
      policyNumber: null,
      effectiveDate: '',
      unavailableReason:
        'Binding is not live yet — the carrier programme has to be in place first. Nothing has been bought and nothing has been charged.',
    }
  },
}

let adapter: RatingAdapter = MockRatingAdapter
export function setRatingAdapter(a: RatingAdapter): void {
  adapter = a
}
export function ratingAdapter(): RatingAdapter {
  return adapter
}

// ───────────────────────────────────────────────────────────────────────────
// THE SCREEN OF TRUTH
// ───────────────────────────────────────────────────────────────────────────

export interface DatedWaiting {
  id: string
  label: string
  days: number
  because: string
  /** The date cover actually starts for this. */
  coveredFrom: Date
}

/** SPEC §5: "waiting periods as dated countdowns" — dates, not durations. */
export function datedWaiting(effective: Date): DatedWaiting[] {
  return WAITING_PERIODS.map((w) => ({
    ...w,
    coveredFrom: new Date(effective.getTime() + w.days * 86_400_000),
  }))
}

export interface PreExistingLine {
  conditionId: string
  name: string
  /** Plain words: what this specifically means for this pet. */
  meaning: string
}

/**
 * SPEC §5: "pre-existing picture declared in plain words, generated from the
 * pet's confirmed conditions".
 *
 * THE POINT OF THIS IS THAT IT IS UNPLEASANT. The commonest reason a pet claim
 * is declined is a pre-existing condition, and the commonest reason the owner
 * is blindsided is that nobody said it in words before they paid. So it is
 * named, per condition, on the screen before the money — and when there is
 * nothing to declare that is said too, rather than leaving a blank space that
 * reads as "nothing is excluded".
 */
export function preExistingPicture(pet: PetProfile): PreExistingLine[] {
  return (pet.conditionIds ?? []).map((id) => {
    const c = KNOWN_CONDITIONS.find((k) => k.id === id)
    const name = c?.name ?? id
    return {
      conditionId: id,
      name,
      meaning: `${name} is already on ${pet.name}'s record, so it will not be covered — nor will anything a vet judges to be caused by it. Everything unrelated still is.`,
    }
  })
}

export function noPreExistingLine(pet: PetProfile): string {
  return `You have not told us about anything diagnosed, so nothing is excluded as pre-existing today. If something is found before ${pet.name}'s cover starts, it would be.`
}

/** The soonest a policy can start: tomorrow, never today. */
export function earliestEffective(now: Date): Date {
  const d = new Date(now.getTime() + 86_400_000)
  d.setUTCHours(0, 0, 0, 0)
  return d
}
