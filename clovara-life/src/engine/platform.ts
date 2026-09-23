import type { PetProfile, Projection, Species } from '../data/types'
import { ALL_BREEDS } from '../data/engine'
import { PRODUCTS, type Product } from '../data/products'
import {
  BASE_RATE,
  DEMO_CLAIMS,
  PLAN_TIERS,
  RIDER_ITEMS,
  RIDER_PRICE,
  type DemoClaim,
  type PlanTier,
  type RiderItem,
} from '../data/coverage'
import { POINT_RULES, REDEMPTIONS, type Redemption } from '../data/rewards'
import { fitnessProvider } from '../fitness/provider'

/**
 * ═══════════════════════════════════════════════════════════════════════════
 * PLATFORM ENGINE
 * ═══════════════════════════════════════════════════════════════════════════
 *
 * Everything the five non-Journey surfaces render is derived here, from the same
 * pet profile and the same Projection that drives the Life Journey. No screen
 * holds its own copy of the truth.
 *
 * Every function in this file is pure. Where a surface needs a number we do not
 * actually measure — step counts, streak days — it is derived from a stable hash
 * of the pet's id and their declared routine, so it is consistent across reloads
 * and consistent with the rest of the profile. Those values are SIMULATED and
 * every screen that shows one says so.
 */

const round = (n: number, dp = 0) => Math.round(n * 10 ** dp) / 10 ** dp
const clamp = (n: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, n))

/** Stable, deterministic hash. Replaces Math.random so output never drifts. */
function hash(s: string): number {
  let h = 2166136261
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i)
    h = Math.imul(h, 16777619)
  }
  return Math.abs(h)
}

/** Deterministic integer in [lo, hi] from a seed string. */
function seeded(seed: string, lo: number, hi: number): number {
  return lo + (hash(seed) % (hi - lo + 1))
}

// ───────────────────────────────────────────────────────────────────────────
// CLOVARA SCORE
// ───────────────────────────────────────────────────────────────────────────

export interface ScoreBand {
  id: string
  label: string
  earned: number
  max: number
  detail: string
}

export interface Score {
  value: number
  bands: ScoreBand[]
  headline: string
  /** The single highest-value thing this owner could change. */
  biggestGap: ScoreBand | null
}

/**
 * The Clovara Score is a PRODUCT CONSTRUCT, not a clinical measure.
 *
 * It is a weighted restatement of the same modifiable inputs that drive the
 * healthy-years projection, scaled 0–100 so it can be tracked week to week and
 * given a target. It has not been validated against outcomes and it does not
 * predict anything on its own — the projection does that, and the score is the
 * projection's inputs made legible.
 *
 * The weights deliberately mirror the engine's evidence tiers. Body condition
 * carries the most because it is the only factor at the `strong` tier. Dental
 * and activity carry less because the evidence behind them is associational and
 * directional respectively. If the score weighted them equally it would be
 * telling a different story from the rest of the product.
 */
export function clovaraScore(profile: PetProfile, projection: Projection): Score {
  const isCat = profile.species === 'cat'
  const bc = projection.bodyCondition

  const weightPts =
    bc === 'ideal' ? 35 : bc === 'lean' ? (isCat ? 20 : 33) : 12

  const dental = profile.dental ?? 'weekly'
  const activity = profile.activity ?? 'moderate'
  const diet = profile.diet ?? 'unsure'
  const dentalPts = dental === 'daily' ? 25 : dental === 'weekly' ? 15 : 5
  const activityPts = activity === 'high' ? 20 : activity === 'moderate' ? 14 : 6
  const dietPts = diet === 'measured' ? 10 : diet === 'free-fed' ? 4 : 6
  const neuterPts = profile.neutered ? 10 : 6

  const bands: ScoreBand[] = [
    {
      id: 'weight',
      label: 'Body condition',
      earned: weightPts,
      max: 35,
      detail: isCat
        ? bc === 'ideal'
          ? 'At ideal, which is where the feline evidence points.'
          : bc === 'lean'
            ? 'Below ideal. In cats, thin carries its own risk.'
            : 'Above ideal, though the cost is smaller in cats than in dogs.'
        : bc === 'ideal'
          ? 'At ideal. The best-evidenced thing you control.'
          : bc === 'lean'
            ? 'Lean, which is the condition associated with the longest healthy years.'
            : 'Above the breed range. This is the biggest single lever here.',
    },
    {
      id: 'dental',
      label: 'Dental routine',
      earned: dentalPts,
      max: 25,
      detail:
        dental === 'daily'
          ? 'Daily, which is the standard the guidelines describe.'
          : dental === 'weekly'
            ? 'Weekly. A reasonable place to build from.'
            : 'Rarely — the most common answer, and the easiest to change.',
    },
    {
      id: 'activity',
      label: 'Activity',
      earned: activityPts,
      max: 20,
      detail:
        activity === 'high'
          ? 'Well above average for the breed.'
          : activity === 'moderate'
            ? 'Steady and regular, which matters more than intensity.'
            : 'Low. Worth building gradually rather than in weekend bursts.',
    },
    {
      id: 'diet',
      label: 'Feeding',
      earned: dietPts,
      max: 10,
      detail:
        diet === 'measured'
          ? 'Measured meals. This is how body condition holds.'
          : diet === 'free-fed'
            ? 'Free fed. Portion control is where weight gain usually starts.'
            : 'Not recorded. Measuring meals is the change with the most behind it.',
    },
    {
      id: 'neuter',
      label: 'Neuter status',
      earned: neuterPts,
      max: 10,
      detail: profile.neutered
        ? 'Recorded. Associated with longer life across large datasets.'
        : 'Intact. Worth a conversation about timing rather than a default date.',
    },
  ]

  const value = bands.reduce((s, b) => s + b.earned, 0)
  const gaps = bands.filter((b) => b.earned < b.max)
  const biggestGap =
    gaps.sort((a, b) => b.max - b.earned - (a.max - a.earned))[0] ?? null

  const headline =
    value >= 85
      ? 'Doing well on everything we can see.'
      : value >= 70
        ? 'On track, with room in one or two places.'
        : value >= 55
          ? 'A few things here are worth a look.'
          : 'Several changes available, and they compound.'

  return { value, bands, headline, biggestGap }
}

// ───────────────────────────────────────────────────────────────────────────
// SHOP
// ───────────────────────────────────────────────────────────────────────────

export interface ProductRec extends Product {
  /** Why this appeared for this pet, in plain language. */
  why: string
  /** The risk card ids it matched. Empty for staples. */
  matched: string[]
  /** Higher sorts first. */
  relevance: number
}

/**
 * The shelf is derived, not merchandised. A product appears because it targets a
 * condition on this pet's own risk cards, or because it belongs to their current
 * life stage. Anything that matches neither is a staple and sorts last.
 */
export function recommendProducts(profile: PetProfile, projection: Projection): ProductRec[] {
  const riskIds = new Set(projection.riskCards.map((r) => r.id))
  const declared = new Set(profile.conditionIds ?? [])
  const stage = projection.currentStage.id

  // Rank the pet's risks so a high-tier, in-window risk pulls its product up.
  const riskWeight = new Map<string, number>()
  projection.riskCards.forEach((r, i) => {
    let w = 10 - i
    if (r.tier === 'high') w += 6
    if (r.mode === 'manage') w += 10
    if (r.mode === 'active') w += 5
    riskWeight.set(r.id, w)
  })

  return PRODUCTS.filter((p) => p.species.includes(profile.species))
    .filter((p) => !p.stages || p.stages.includes(stage))
    // A breed-specific item only earns a place if it matches something on this
    // pet's own risk cards. Otherwise the shelf offers fold wipes to a Golden.
    .filter(
      (p) =>
        p.universal ||
        p.stages?.includes(stage) ||
        p.targets.some((t) => riskIds.has(t) || declared.has(t)),
    )
    .map((p) => {
      const matched = p.targets.filter((t) => riskIds.has(t) || declared.has(t))
      const matchScore = matched.reduce((s, m) => s + (riskWeight.get(m) ?? 4), 0)
      const stageBonus = p.stages?.includes(stage) ? 14 : 0

      let why: string
      if (matched.length > 0) {
        const card = projection.riskCards.find((r) => r.id === matched[0])
        const name = (card?.name ?? matched[0]).toLowerCase()
        why = declared.has(matched[0])
          ? `Because ${profile.name} is already managing ${name}`
          : card?.mode === 'active'
            ? `${capitalise(name)} is in its window now`
            : `For ${profile.name}'s ${name} watch`
      } else if (stageBonus) {
        why = `For the ${projection.currentStage.label.toLowerCase()} stage`
      } else {
        why = `A staple for ${profile.species === 'dog' ? 'dogs' : 'cats'} at this age`
      }

      return { ...p, why, matched, relevance: matchScore + stageBonus }
    })
    .sort((a, b) => b.relevance - a.relevance || a.price - b.price)
}

function capitalise(s: string) {
  return s.charAt(0).toUpperCase() + s.slice(1)
}

// ───────────────────────────────────────────────────────────────────────────
// COVERAGE
// ───────────────────────────────────────────────────────────────────────────

export interface CoverageView {
  /** True for the seeded demo pets. Added pets get a quote, not a policy. */
  hasPolicy: boolean
  policyNumber: string | null
  tier: PlanTier
  monthlyPremium: number
  riderPrice: number
  totalMonthly: number
  /** How the premium was arrived at. Shown in full — this is the point. */
  breakdown: { label: string; value: string; note: string }[]
  riderItems: RiderItem[]
  riderTotal: number
  claim: DemoClaim | null
  /** Breed risks and whether the plan responds to them. */
  riskCoverage: { name: string; covered: boolean; note: string }[]
}

/** Median baseline healthy years for a species, used as the breed risk anchor. */
function speciesMedian(species: Species): number {
  const mids = ALL_BREEDS.filter((b) => b.species === species)
    .map((b) => (b.baseline.low + b.baseline.high) / 2)
    .sort((a, b) => a - b)
  return mids[Math.floor(mids.length / 2)]
}

/**
 * ILLUSTRATIVE PRICING. See the warning at the top of data/coverage.ts.
 *
 * This demonstrates that rate responds to species, size, age and breed risk. It
 * is not a filed rate, carries no expense or jurisdictional loading, and must
 * never be shown as a quote.
 */
export function buildCoverage(
  profile: PetProfile,
  projection: Projection,
  tierId = 'complete',
): CoverageView {
  const breed = projection.breed
  const tier = PLAN_TIERS.find((t) => t.id === tierId) ?? PLAN_TIERS[1]
  const base = BASE_RATE[profile.species][breed.sizeClass]

  const age = projection.ageYears
  const ageFactor = 1 + clamp(age - 2, 0, 16) * 0.048
  const breedMid = (breed.baseline.low + breed.baseline.high) / 2
  const breedFactor = clamp(speciesMedian(profile.species) / breedMid, 0.85, 1.45)
  const declaredCount = (profile.conditionIds ?? []).length
  const conditionFactor = 1 + Math.min(declaredCount * 0.11, 0.33)

  const monthlyPremium = round(base * ageFactor * breedFactor * conditionFactor * tier.factor, 2)
  const riderPrice = RIDER_PRICE[profile.species]

  const breakdown = [
    {
      label: `${cap(breed.sizeClass)} ${profile.species}`,
      value: `$${base.toFixed(2)}`,
      note: 'Base rate by species and size class.',
    },
    {
      label: `Age ${Math.floor(age)}`,
      value: `×${ageFactor.toFixed(2)}`,
      note: 'Rises with age, as claim frequency does.',
    },
    {
      label: breed.name,
      value: `×${breedFactor.toFixed(2)}`,
      note:
        breedFactor > 1.02
          ? 'Above the species median for breed risk.'
          : breedFactor < 0.98
            ? 'Below the species median for breed risk.'
            : 'At the species median for breed risk.',
    },
    ...(declaredCount
      ? [
          {
            label: `${declaredCount} declared condition${declaredCount > 1 ? 's' : ''}`,
            value: `×${conditionFactor.toFixed(2)}`,
            note: 'Pre-existing conditions are excluded from cover, and are priced transparently rather than hidden.',
          },
        ]
      : []),
    {
      label: tier.name,
      value: `×${tier.factor.toFixed(2)}`,
      note: `${tier.reimbursement}% reimbursement, $${tier.deductible} deductible.`,
    },
  ]

  const riderItems = RIDER_ITEMS.filter(
    (r) => r.species.includes(profile.species) && r.stages.includes(projection.currentStage.id),
  )
    // Do not offer to reimburse a procedure this pet has already had.
    .filter((r) => !(r.id === 'neuter-consult' && profile.neutered))
  const riderTotal = riderItems.reduce((s, r) => s + r.allowance, 0)

  const riskCoverage = projection.riskCards.slice(0, 4).map((r) => {
    const isDeclared = (profile.conditionIds ?? []).includes(r.id)
    return {
      name: r.name,
      covered: !isDeclared,
      note: isDeclared
        ? 'Already on the record, so excluded as pre-existing. We say so up front rather than at claim time.'
        : 'Covered if it develops, subject to the waiting period.',
    }
  })

  return {
    hasPolicy: !!profile.demo,
    policyNumber: profile.demo ? `CLV-${200000 + (hash(profile.id) % 99999)}` : null,
    tier,
    monthlyPremium,
    riderPrice,
    totalMonthly: round(monthlyPremium + riderPrice, 2),
    breakdown,
    riderItems,
    riderTotal,
    claim: DEMO_CLAIMS.find((c) => c.petId === profile.id) ?? null,
    riskCoverage,
  }
}

function cap(s: string) {
  return s.charAt(0).toUpperCase() + s.slice(1)
}

// ───────────────────────────────────────────────────────────────────────────
// REWARDS
// ───────────────────────────────────────────────────────────────────────────

export interface RewardsView {
  points: number
  weekPoints: number
  streaks: { label: string; value: string; note: string }[]
  redemptions: (Redemption & { affordable: boolean; recommended: boolean })[]
  rules: typeof POINT_RULES
  /** How many of the earning behaviours also move the projection. */
  alignedCount: number
}

/**
 * Points and streaks. SIMULATED, but derived from the pet's declared routine, so
 * a pet whose owner brushes daily has a long dental streak and a pet whose owner
 * rarely brushes does not. Stable across reloads.
 */
export function buildRewards(profile: PetProfile, projection: Projection): RewardsView {
  const dentalDays =
    (profile.dental ?? 'weekly') === 'daily' ? seeded(profile.id + 'd', 24, 61) : (profile.dental ?? 'weekly') === 'weekly' ? seeded(profile.id + 'd', 4, 9) : seeded(profile.id + 'd', 0, 2)
  const walkDays =
    (profile.activity ?? 'moderate') === 'high' ? seeded(profile.id + 'w', 18, 44) : (profile.activity ?? 'moderate') === 'moderate' ? seeded(profile.id + 'w', 6, 16) : seeded(profile.id + 'w', 1, 4)

  const points =
    600 +
    dentalDays * 15 +
    walkDays * 10 +
    (profile.diet === 'measured' ? 300 : 0) +
    seeded(profile.id + 'p', 0, 400)
  const weekPoints = Math.min(dentalDays, 7) * 15 + Math.min(walkDays, 7) * 10 + (profile.demo ? 60 : 0)

  const riskIds = new Set(projection.riskCards.map((r) => r.id))
  const declared = new Set(profile.conditionIds ?? [])

  const redemptions = REDEMPTIONS.filter(
    (r) => !r.species || r.species.includes(profile.species),
  ).map((r) => ({
    ...r,
    affordable: points >= r.cost,
    recommended: !!r.targets?.some((t) => riskIds.has(t) || declared.has(t)),
  })).sort((a, b) => Number(b.recommended) - Number(a.recommended) || a.cost - b.cost)

  return {
    points,
    weekPoints,
    streaks: [
      {
        label: 'Dental streak',
        value: `${dentalDays}`,
        note: dentalDays > 20 ? 'days running' : dentalDays > 3 ? 'days this month' : 'days — room to build',
      },
      { label: 'Activity goal', value: `${walkDays}`, note: 'days met' },
      {
        label: 'Care visits',
        value: projection.currentStage.status === 'current' && projection.ageYears > 1 ? '2/2' : '1/1',
        note: 'done this year',
      },
    ],
    redemptions,
    rules: POINT_RULES,
    alignedCount: POINT_RULES.filter((r) => r.movesProjection).length,
  }
}

// ───────────────────────────────────────────────────────────────────────────
// COMPANION
// ───────────────────────────────────────────────────────────────────────────

export interface CompanionMessage {
  from: 'user' | 'ai'
  text: string
  /** A recall block — the thing that only exists because we hold the history. */
  recall?: { label: string; text: string }
  actions?: string[]
}

/**
 * The companion thread is scripted, but every specific in it comes from the
 * pet's own record — the declared condition, the risk card that is in its window
 * right now, the breed's actual watch signs. Swap the pet and the conversation
 * changes, because the memory changes.
 *
 * The guardrail is structural, not cosmetic: the companion informs and routes to
 * a licensed vet. It never diagnoses, and the closing note says the conversation
 * is firewalled from underwriting and claims.
 */
export function buildCompanion(profile: PetProfile, projection: Projection): CompanionMessage[] {
  const declaredCard = projection.riskCards.find((r) => r.mode === 'manage')
  const activeCard = projection.riskCards.find((r) => r.mode === 'active')
  // Every shipped breed has conditions, but never index blind in front of an audience.
  const focus = declaredCard ?? activeCard ?? projection.riskCards[0]
  if (!focus) return []
  const them = profile.sex === 'female' ? 'her' : 'him'
  const they = profile.sex === 'female' ? 'she' : 'he'
  const theyCap = profile.sex === 'female' ? 'She' : 'He'
  const their = profile.sex === 'female' ? 'her' : 'his'

  const symptom = firstClause(focus.watch)

  return [
    {
      from: 'user',
      // Watch signs are clinical fragments of every shape — noun phrases
      // ("stiffness after rest"), gerunds ("jumping less"), comparatives
      // ("slower to rise after a nap"). Setting the fragment off after a dash
      // reads correctly for all of them; trying to conjugate them does not.
      text: `Something has been off with ${profile.name} the last few days — ${symptom}. Should I be worried?`,
    },
    {
      from: 'ai',
      text: `Thanks for flagging it — that is worth paying attention to.`,
      recall: declaredCard
        ? {
            label: `From ${profile.name}'s record`,
            text: `${declaredCard.name} is already noted on ${their} file, with a plan to monitor as ${they} ages. What you are describing fits that picture.`,
          }
        : {
            label: `From ${profile.name}'s record`,
            text: `${theyCap} is ${projection.ageYears} and a ${projection.breed.name}, which puts ${them} inside the usual window for ${focus.name.toLowerCase()} — ${focus.window.toLowerCase()}.`,
          },
    },
    {
      from: 'ai',
      text: `${focus.action} I would also watch for ${secondClause(focus.watch)}. This is worth a vet's eyes — not an emergency, but soon.`,
      actions: ['Book telehealth vet', `Send ${profile.name}'s history summary`],
    },
    { from: 'user', text: 'Book it — and yes, send the summary.' },
    {
      from: 'ai',
      text: `Done. Dr. Chen has a video slot tomorrow at 5:30pm. I have put together a one-page summary for the visit: ${their} ${focus.name.toLowerCase()} notes, the last three weigh-ins, ${their} current ${projection.breed.species === 'cat' ? 'diet and litter-box' : 'activity'} trend, and what ${they} is currently taking.`,
    },
  ]
}

/** "Slower to rise after a nap, bunny-hopping at a run." → first clause. */
function firstClause(watch: string): string {
  return watch.split(/[,;.]/)[0].trim().toLowerCase()
}
function secondClause(watch: string): string {
  const parts = watch.split(/[,;.]/).map((p) => p.trim()).filter(Boolean)
  return (parts[1] ?? parts[0]).toLowerCase()
}

// ───────────────────────────────────────────────────────────────────────────
// HOME
// ───────────────────────────────────────────────────────────────────────────

export interface HomeView {
  score: Score
  steps: number
  stepsTrend: number[]
  trendDown: boolean
  nudge: { eyebrow: string; title: string; body: string }
  comingUp: { title: string; detail: string; covered: boolean } | null
}

export function buildHome(profile: PetProfile, projection: Projection): HomeView {
  const score = clovaraScore(profile, projection)

  // Through the adapter (SPEC §6.9), not from a hash in here. When a partner
  // SDK lands it implements FitnessProvider and this line does not change.
  const reading = fitnessProvider().activity(profile, new Date())
  const steps = reading.steps
  const trend = reading.trend
  const trendDown = reading.belowNormal

  const gap = score.biggestGap
  const nudge = trendDown
    ? {
        eyebrow: 'Worth watching',
        title: `${profile.name}'s activity is down ${seeded(profile.id + 'n', 12, 24)}% this week`,
        body: projection.riskCards.find((r) => r.mode === 'manage')
          ? `Unusual for ${profile.sex === 'female' ? 'her' : 'his'} routine. Given the ${projection.riskCards.find((r) => r.mode === 'manage')!.name.toLowerCase()} already on file, keep an eye on stiffness after walks.`
          : `Unusual for ${profile.sex === 'female' ? 'her' : 'his'} routine. Worth watching for a few more days before it means anything.`,
      }
    : gap
      ? {
          eyebrow: 'Biggest lever',
          title: gapTitle(gap.id, profile.name),
          body: gap.detail,
        }
      : {
          eyebrow: 'On track',
          title: `Nothing needs attention this week`,
          body: `${profile.name} is doing well on everything we can see from here.`,
        }

  const rider = RIDER_ITEMS.find(
    (r) => r.species.includes(profile.species) && r.stages.includes(projection.currentStage.id),
  )

  return {
    score,
    steps,
    stepsTrend: trend,
    trendDown,
    nudge,
    comingUp: rider
      ? { title: rider.label, detail: rider.because, covered: true }
      : null,
  }
}

function gapTitle(id: string, name: string): string {
  switch (id) {
    case 'weight':
      return `${name}'s weight is the one to work on`
    case 'dental':
      return `Dental care is the easiest win for ${name}`
    case 'activity':
      return `A bit more movement would move the number`
    case 'diet':
      return `Measured meals would help ${name} hold condition`
    default:
      return `One thing worth a conversation with your vet`
  }
}
