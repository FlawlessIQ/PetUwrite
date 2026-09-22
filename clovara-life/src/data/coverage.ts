import type { SizeClass, Species } from './types'

/**
 * ═══════════════════════════════════════════════════════════════════════════
 * COVERAGE — ILLUSTRATIVE PRICING, NOT A QUOTE
 * ═══════════════════════════════════════════════════════════════════════════
 *
 * READ THIS BEFORE SHOWING ANYONE A NUMBER FROM THIS FILE.
 *
 * The premiums this produces are a demonstration of a pricing *shape* — that
 * rate varies with species, size, age and breed risk — not a rate. They are not
 * filed, not actuarially derived, and carry no loss-cost, expense, or
 * jurisdictional loading. Nothing here has been through a rate filing and it
 * must never be presented as a quote or a binding price. The UI labels every
 * figure accordingly and that label is not decorative.
 *
 * What IS worth showing: the wellness rider line items are generated from the
 * pet's actual life stage, so the routine care a policy reimburses lines up with
 * the care the Life Journey says matters right now. That link is real and it is
 * the point of the screen.
 *
 * ───────────────────────────────────────────────────────────────────────────
 * REGULATORY NOTES CARRIED IN THE UI COPY
 * ───────────────────────────────────────────────────────────────────────────
 * - Membership and insurance are priced separately. Rewards points redeem
 *   toward products and care perks, never toward premium — anti-rebating rules
 *   in most states make premium discounts for behaviour a filing question, and
 *   the demo should not imply otherwise.
 * - The wellness rider is a non-insurance benefit in many states and is
 *   presented as reimbursement for routine care, not as insurance coverage.
 * - Companion conversations are shown as firewalled from underwriting and
 *   claims. That separation is a product commitment in the mockup and the copy
 *   here keeps it.
 */

export interface RiderItem {
  id: string
  label: string
  /** Illustrative annual reimbursement allowance, in dollars. */
  allowance: number
  /** Which life stage ids this appears for. */
  stages: string[]
  species: Species[]
  /** Ties the line back to the guidance the Life Journey is already showing. */
  because: string
}

/**
 * Wellness rider line items. These mirror the AAHA-informed stage templates in
 * engine.ts, so what the policy reimburses matches what the journey recommends.
 */
export const RIDER_ITEMS: RiderItem[] = [
  // Dogs
  {
    id: 'puppy-series',
    label: 'Puppy vaccination series and exams',
    allowance: 220,
    stages: ['puppy'],
    species: ['dog'],
    because: 'The puppy stage is a run of visits in a short window — this is where a rider earns its keep.',
  },
  {
    id: 'neuter-consult',
    label: 'Neutering consultation and procedure',
    allowance: 300,
    stages: ['puppy', 'young-adult'],
    species: ['dog', 'cat'],
    because: 'In dogs over about 45 lb, timing is associated with joint disorder risk — worth a conversation, not a default date.',
  },
  {
    id: 'annual-exam',
    label: 'Annual exam and core vaccines',
    allowance: 85,
    stages: ['young-adult', 'mature-adult'],
    species: ['dog', 'cat'],
    because: 'The guidelines ask for an exam every six to twelve months through adulthood.',
  },
  {
    id: 'baseline-bloods',
    label: 'Baseline bloodwork and urinalysis',
    allowance: 110,
    stages: ['young-adult'],
    species: ['dog', 'cat'],
    because: 'Baseline values taken while your pet is well are what make later results readable.',
  },
  {
    id: 'dental-clean',
    label: 'Professional dental cleaning',
    allowance: 320,
    stages: ['young-adult', 'mature-adult', 'senior'],
    species: ['dog', 'cat'],
    because: 'Most dogs and cats seen in practice are diagnosed with dental disease. This is the most-used line on the rider.',
  },
  {
    id: 'annual-bloods',
    label: 'Annual blood panel and urinalysis',
    allowance: 140,
    stages: ['mature-adult'],
    species: ['dog', 'cat'],
    because: 'The middle years are when things start appearing on bloodwork before they appear at home.',
  },
  {
    id: 'senior-panel',
    label: 'Senior panel, twice yearly',
    allowance: 260,
    stages: ['senior'],
    species: ['dog', 'cat'],
    because: 'Senior guidance is exams at least every six months, with bloodwork and urinalysis alongside.',
  },
  {
    id: 'bp-thyroid',
    label: 'Blood pressure and thyroid testing',
    allowance: 95,
    stages: ['senior'],
    species: ['dog', 'cat'],
    because: 'Added to the senior panel by the guidelines, and easy to leave off if nobody prompts for it.',
  },
  {
    id: 'parasite',
    label: 'Parasite prevention and testing',
    allowance: 130,
    stages: ['puppy', 'young-adult', 'mature-adult', 'senior'],
    species: ['dog'],
    because: 'Heartworm and tick-borne testing annually, with prevention through the year.',
  },
  // Cats
  {
    id: 'kitten-series',
    label: 'Kitten vaccination series and retrovirus testing',
    allowance: 200,
    stages: ['kitten'],
    species: ['cat'],
    because: 'Retrovirus testing is strongly recommended in the first year and is easy to miss later.',
  },
  {
    id: 'cat-dental-assess',
    label: 'Full oral assessment under anaesthesia',
    allowance: 340,
    stages: ['mature-adult', 'senior'],
    species: ['cat'],
    because: 'Dental disease is the most commonly diagnosed problem in cats in primary care.',
  },
  {
    id: 'cat-renal-panel',
    label: 'Kidney panel with urine concentration',
    allowance: 150,
    stages: ['mature-adult', 'senior'],
    species: ['cat'],
    because: 'Blood values and urine concentration together — one without the other misses early kidney disease.',
  },
]

/**
 * Illustrative base monthly rate by species and size, before age and breed
 * adjustment. Shape only. See the warning at the top of this file.
 */
export const BASE_RATE: Record<Species, Record<SizeClass, number>> = {
  dog: { toy: 26, small: 29, medium: 34, large: 41, giant: 52 },
  cat: { toy: 19, small: 21, medium: 23, large: 26, giant: 28 },
}

export interface PlanTier {
  id: string
  name: string
  reimbursement: number
  deductible: number
  annualLimit: string
  /** Multiplier applied to the base rate. */
  factor: number
  blurb: string
}

export const PLAN_TIERS: PlanTier[] = [
  {
    id: 'essential',
    name: 'Clovara Essential',
    reimbursement: 70,
    deductible: 500,
    annualLimit: '$5,000',
    factor: 0.72,
    blurb: 'Accidents and illness, with a higher deductible.',
  },
  {
    id: 'complete',
    name: 'Clovara Complete',
    reimbursement: 90,
    deductible: 250,
    annualLimit: 'Unlimited',
    factor: 1,
    blurb: 'Accidents and illness at the level most members choose.',
  },
]

/** Illustrative monthly cost of the wellness rider, by species. */
export const RIDER_PRICE: Record<Species, number> = { dog: 14, cat: 11 }

export interface DemoClaim {
  petId: string
  title: string
  submitted: string
  approvedHours: number
  paid: number
  invoice: number
  status: 'paid'
  note: string
}

/**
 * Claim history for the seeded demo pets only. Pets added during a demo get an
 * honest empty state rather than a fabricated history.
 */
export const DEMO_CLAIMS: DemoClaim[] = [
  {
    petId: 'demo-max',
    title: 'Torn dewclaw',
    submitted: 'Aug 2, 9:14am',
    approvedHours: 4,
    invoice: 380,
    paid: 342,
    status: 'paid',
    note: 'Photo of the invoice, nothing else. Auto-reviewed, no adjuster call.',
  },
  {
    petId: 'demo-winston',
    title: 'Corneal ulcer, left eye',
    submitted: 'May 19, 7:42pm',
    approvedHours: 3,
    invoice: 465,
    paid: 419,
    status: 'paid',
    note: 'Submitted from the emergency clinic car park. Paid before the follow-up appointment.',
  },
  {
    petId: 'demo-luna',
    title: 'Dental cleaning with two extractions',
    submitted: 'Jun 11, 11:05am',
    approvedHours: 6,
    invoice: 690,
    paid: 594,
    status: 'paid',
    note: 'Rider covered the cleaning; the extractions went through the illness side.',
  },
]

export const COVERAGE_DISCLAIMER =
  'Illustrative pricing shown to demonstrate how rate varies with species, size, age and breed. Not a quote and not a filed rate.'
