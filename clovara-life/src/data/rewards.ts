import type { Species } from './types'

/**
 * ═══════════════════════════════════════════════════════════════════════════
 * REWARDS
 * ═══════════════════════════════════════════════════════════════════════════
 *
 * THE HARD RULE, AND IT IS A REGULATORY ONE, NOT A PRODUCT PREFERENCE:
 * points redeem toward products and care perks. Never toward premium. Anti-
 * rebating statutes in most states treat a premium reduction given for
 * behaviour as a filing question, and a demo that shows points buying down a
 * premium is showing something Clovara could not ship. Every redemption in this
 * file is a product, a service, or a copay on the non-insurance wellness rider.
 *
 * The streak counts are SIMULATED. There is no wearable and no tracking in this
 * build. They are derived deterministically from the pet's declared dental and
 * activity routine, so they are stable across reloads and consistent with the
 * rest of the profile rather than random — but they are a demonstration of the
 * mechanic, not observed data. The UI says so.
 */

export interface PointRule {
  id: string
  label: string
  points: number
  cadence: 'daily' | 'weekly' | 'monthly' | 'per visit' | 'per order'
  /** Whether this behaviour also moves the healthy-years projection. */
  movesProjection: boolean
}

/**
 * Points are weighted to mirror the engine's evidence tiers — the behaviours
 * with the strongest evidence behind them earn the most. That alignment is the
 * whole design: the rewarded behaviours are the ones that reduce claims.
 */
export const POINT_RULES: PointRule[] = [
  {
    id: 'weigh-in',
    label: 'Monthly weigh-in logged',
    points: 150,
    // Was 'weekly' under a label saying monthly (UAT run 1, D15).
    cadence: 'monthly',
    movesProjection: true,
  },
  {
    id: 'brush',
    label: 'Teeth brushed',
    points: 15,
    cadence: 'daily',
    movesProjection: true,
  },
  {
    id: 'activity-goal',
    label: 'Daily activity goal met',
    points: 10,
    cadence: 'daily',
    movesProjection: true,
  },
  {
    id: 'wellness-visit',
    label: 'Wellness visit completed',
    points: 500,
    cadence: 'per visit',
    movesProjection: false,
  },
  {
    id: 'dental-clean',
    label: 'Professional dental cleaning',
    points: 600,
    cadence: 'per visit',
    movesProjection: false,
  },
  {
    id: 'screening',
    label: 'Age-appropriate screening done',
    points: 450,
    cadence: 'per visit',
    movesProjection: false,
  },
  {
    id: 'order',
    label: 'Shop order',
    points: 0,
    cadence: 'per order',
    movesProjection: false,
  },
]

export interface Redemption {
  id: string
  label: string
  detail: string
  cost: number
  emoji: string
  /** 'product' | 'care' — never 'premium'. There is no premium option. */
  kind: 'product' | 'care'
  /** Set when this redemption is only offered because of the pet's profile. */
  targets?: string[]
  /** Omit for items that suit both species. */
  species?: Species[]
}

export const REDEMPTIONS: Redemption[] = [
  {
    id: 'r-joint',
    label: 'Hip & Joint chews — free bag',
    detail: 'One month supply, delivered',
    cost: 800,
    emoji: '🦴',
    kind: 'product',
    species: ['dog'],
    targets: ['hip-dysplasia', 'arthritis', 'elbow-dysplasia', 'ccl'],
  },
  {
    id: 'r-telehealth',
    label: 'Telehealth vet visit',
    detail: 'Any licensed partner vet, no copay',
    cost: 600,
    emoji: '📹',
    kind: 'care',
  },
  {
    id: 'r-dental-kit',
    label: 'Dental care kit',
    detail: 'Enzymatic paste and two brushes',
    cost: 400,
    emoji: '🦷',
    kind: 'product',
    targets: ['periodontal'],
  },
  {
    id: 'r-wellness-copay',
    label: 'Wellness visit copay waived',
    detail: 'On your wellness rider — not on your premium',
    cost: 500,
    emoji: '🩺',
    kind: 'care',
  },
  {
    id: 'r-grooming',
    label: 'Grooming kit',
    detail: 'Oatmeal shampoo, brush and nail clippers',
    cost: 450,
    emoji: '🧼',
    kind: 'product',
  },
  {
    id: 'r-screening',
    label: '$50 off senior screening',
    detail: 'Bloodwork, urinalysis and blood pressure',
    cost: 900,
    emoji: '🔬',
    kind: 'care',
    targets: ['ckd', 'hyperthyroidism', 'diabetes', 'arthritis'],
  },
  {
    id: 'r-fountain',
    label: 'Circulating water fountain',
    detail: 'Encourages drinking through the day',
    cost: 1100,
    emoji: '⛲',
    kind: 'product',
    species: ['cat'],
    targets: ['ckd', 'urinary'],
  },
  {
    id: 'r-clotag',
    label: '$40 off a CloTag',
    detail: 'Activity, rest and resting respiratory rate',
    cost: 1500,
    emoji: '📍',
    kind: 'product',
  },
]

export const REWARDS_DISCLAIMER =
  'Points redeem toward products and care services only, never toward your premium. Streak data in this preview is simulated.'
