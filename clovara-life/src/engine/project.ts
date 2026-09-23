import type {
  ActivityLevel,
  BodyCondition,
  Breed,
  DentalRoutine,
  EvidenceTier,
  Lever,
  LifeStage,
  OutdoorAccess,
  PetProfile,
  Projection,
  RiskCard,
  SizeClass,
} from '../data/types'
import {
  ACTIVITY_DELTAS,
  CAT_STAGE_BOUNDS,
  CAT_STAGE_TEMPLATES,
  DENTAL_DELTAS,
  DOG_STAGE_BOUNDS,
  DOG_STAGE_TEMPLATES,
  EVIDENCE_LABELS,
  JOINT_CONDITION_IDS,
  JOINT_RISK_WEIGHT_LB,
  KNOWN_CONDITIONS,
  LEVER_CITATIONS,
  MAX_CONDITION_PENALTY,
  MAX_SWING,
  NEUTER_AGE_CITATION,
  NEUTER_DELTA,
  OUTDOOR_DELTAS,
  WEIGHT_DELTAS,
  bodyConditionFromScore,
  findBreed,
  outdoorAgeTaper,
} from '../data/engine'

const round = (n: number, dp = 1) => Math.round(n * 10 ** dp) / 10 ** dp
const clamp = (n: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, n))

/** Age in years, to one decimal place. Pure — the reference date is injected. */
export function ageInYears(birthDate: string, now: Date = new Date()): number {
  const born = new Date(birthDate)
  if (Number.isNaN(born.getTime())) return 0
  const ms = now.getTime() - born.getTime()
  return Math.max(0, round(ms / (365.2425 * 24 * 60 * 60 * 1000), 2))
}

/**
 * Reads current weight against the breed's typical adult range.
 * Returns 'ideal' for anything inside the range, with a small tolerance band.
 */
export function readBodyCondition(weightLb: number, breed: Breed): BodyCondition {
  const { low, high } = breed.weight
  if (weightLb <= 0) return 'ideal'
  if (weightLb < low * 0.92) return 'lean'
  if (weightLb > high * 1.12) return 'overweight'
  if (weightLb > high) return 'overweight'
  if (weightLb < low) return 'lean'
  return 'ideal'
}

function weightNote(
  condition: BodyCondition,
  breed: Breed,
  weightLb: number,
  fromSilhouette: boolean,
): string {
  const range = `${breed.weight.low}–${breed.weight.high} lb`
  if (fromSilhouette) {
    const said =
      condition === 'overweight'
        ? 'carrying extra weight'
        : condition === 'lean'
          ? 'on the lean side'
          : 'in good shape'
    return weightLb > 0
      ? `You said ${said} — ${weightLb} lb, against a typical adult range of ${range}.`
      : `You said ${said}. Typical adult range for the breed is ${range}.`
  }
  if (weightLb <= 0) {
    return `No weight yet. Typical adult range for the breed is ${range}.`
  }
  if (condition === 'overweight') {
    return `${weightLb} lb sits above the typical adult range for the breed (${range}).`
  }
  if (condition === 'lean') {
    return `${weightLb} lb sits below the typical adult range for the breed (${range}).`
  }
  return `${weightLb} lb sits within the typical adult range for the breed (${range}).`
}

function weightDeltaFor(species: 'dog' | 'cat', size: SizeClass, condition: BodyCondition): number {
  const table = WEIGHT_DELTAS[species]
  const row = table[size] ?? table.default
  return row[condition]
}

// ───────────────────────────────────────────────────────────────────────────
// Life stages
// ───────────────────────────────────────────────────────────────────────────

interface Bound {
  id: string
  from: number
  to: number | null
}

function dogBounds(breed: Breed, baselineMid: number): Bound[] {
  const { puppyEnd, youngAdultEnd } = DOG_STAGE_BOUNDS[breed.sizeClass]
  // AAHA 2019: senior is the last 25% of estimated lifespan.
  const seniorStart = round(Math.max(youngAdultEnd + 1, baselineMid * 0.75), 1)
  return [
    { id: 'puppy', from: 0, to: puppyEnd },
    { id: 'young-adult', from: puppyEnd, to: youngAdultEnd },
    { id: 'mature-adult', from: youngAdultEnd, to: seniorStart },
    { id: 'senior', from: seniorStart, to: null },
  ]
}

function catBounds(): Bound[] {
  // AAHA/AAFP 2021 uses fixed ages for cats.
  return [
    { id: 'kitten', from: 0, to: CAT_STAGE_BOUNDS.kittenEnd },
    { id: 'young-adult', from: CAT_STAGE_BOUNDS.kittenEnd, to: CAT_STAGE_BOUNDS.youngAdultEnd },
    { id: 'mature-adult', from: CAT_STAGE_BOUNDS.youngAdultEnd, to: CAT_STAGE_BOUNDS.matureAdultEnd },
    { id: 'senior', from: CAT_STAGE_BOUNDS.matureAdultEnd, to: null },
  ]
}

/**
 * Breed-specific recommendations for a stage: any condition whose onset window
 * overlaps the stage, phrased as watch-for or manage depending on whether the
 * owner has already declared it.
 */
function breedRecsForStage(
  breed: Breed,
  bound: Bound,
  declared: Set<string>,
  limit: number,
  /** Mutated as we walk the stages so a condition is raised once, not four times. */
  alreadyRaised: Set<string>,
): string[] {
  const to = bound.to ?? 99
  const picked = breed.conditions
    .filter((c) => !alreadyRaised.has(c.id))
    .filter((c) => c.onset[0] < to && c.onset[1] >= bound.from)
    .sort((a, b) => (a.tier === b.tier ? a.onset[0] - b.onset[0] : a.tier === 'high' ? -1 : 1))
    .slice(0, limit)

  for (const c of picked) alreadyRaised.add(c.id)

  return picked.map((c) => {
    const known = declared.has(c.id)
    const lead = known ? `${c.name} is already on the record` : c.name
    return `${lead} — ${c.action}`
  })
}

function buildStages(breed: Breed, age: number, baselineMid: number, declared: Set<string>): LifeStage[] {
  const bounds = breed.species === 'dog' ? dogBounds(breed, baselineMid) : catBounds()
  const templates = breed.species === 'dog' ? DOG_STAGE_TEMPLATES : CAT_STAGE_TEMPLATES
  const alreadyRaised = new Set<string>()

  return bounds.map((bound) => {
    const t = templates[bound.id]
    const to = bound.to
    const status: LifeStage['status'] =
      to !== null && age >= to ? 'past' : age >= bound.from ? 'current' : 'future'

    // Past stages carry a shorter note; current and future carry the full plan.
    const careCount = status === 'past' ? 2 : 3
    const breedCount = status === 'past' ? 1 : 2
    const recommendations = [
      ...t.care.slice(0, careCount),
      ...breedRecsForStage(breed, bound, declared, breedCount, alreadyRaised),
    ]

    return {
      id: t.id,
      label: t.label,
      from: bound.from,
      to,
      status,
      summary: t.summary,
      recommendations,
    }
  })
}

// ───────────────────────────────────────────────────────────────────────────
// Risk cards
// ───────────────────────────────────────────────────────────────────────────

function windowLabel(onset: [number, number], age: number): string {
  const [a, b] = onset
  if (age >= a && age <= b) return `In the window now — ages ${a} to ${b}`
  if (age < a) {
    const years = round(a - age, 1)
    return years <= 1 ? `Coming up — from about age ${a}` : `Watch from age ${a} to ${b}`
  }
  return `Typical window was ages ${a} to ${b}`
}

/**
 * Age-at-neutering framing for the joint cards, per Hart 2020.
 *
 * Deliberately narrow. It applies to dogs only, to the breeds whose typical
 * adult size puts them in Hart's ≥20 kg group, and only to the three joint
 * disorders Hart actually examined. It says what to watch and what to raise
 * with a vet. It never moves the projection, and it never tells an owner they
 * made the wrong call — the decision is years behind them and was usually their
 * vet's to make.
 */
function neuterAgeContext(breed: Breed, profile: PetProfile): RiskCard['context'] | undefined {
  if (breed.species !== 'dog' || !profile.neutered) return undefined
  const band = profile.neuterAgeBand
  if (!band || band === 'unsure') return undefined

  const typicalAdultLb = (breed.weight.low + breed.weight.high) / 2
  if (typicalAdultLb < JOINT_RISK_WEIGHT_LB) return undefined

  const text =
    band === 'under-6m'
      ? 'Neutered before six months. In dogs of this adult size, that timing is associated with a higher incidence of joint disorders — enough that it is worth watching for stiffness and lameness earlier than you otherwise would, and worth mentioning at the next exam. It is an association in a retrospective study, not a verdict, and nothing about it is undoable.'
      : band === '6-11m'
        ? 'Neutered between six and twelve months. In dogs of this adult size the joint-disorder association is weaker at this timing than before six months, but it is not absent. Worth a mention at the next exam rather than a worry.'
        : 'Neutered at a year or later, which in dogs of this adult size is the timing least associated with joint disorders in the study below.'

  return { text, source: NEUTER_AGE_CITATION }
}

function buildRiskCards(
  breed: Breed,
  age: number,
  declared: Set<string>,
  profile: PetProfile,
): RiskCard[] {
  const jointContext = neuterAgeContext(breed, profile)

  return breed.conditions
    .map((c) => {
      const inWindow = age >= c.onset[0] && age <= c.onset[1]
      const mode: RiskCard['mode'] = declared.has(c.id) ? 'manage' : inWindow ? 'active' : 'watch'
      return {
        id: c.id,
        name: c.name,
        onset: c.onset,
        tier: c.tier,
        watch: c.watch,
        action: declared.has(c.id)
          ? KNOWN_CONDITIONS.find((k) => k.id === c.id)?.managing ?? c.action
          : c.action,
        mode,
        window: windowLabel(c.onset, age),
        confidence: c.confidence,
        context: JOINT_CONDITION_IDS.has(c.id) ? jointContext : undefined,
      }
    })
    .sort((a, b) => {
      const rank = (r: RiskCard) => (r.mode === 'manage' ? 0 : r.mode === 'active' ? 1 : 2)
      if (rank(a) !== rank(b)) return rank(a) - rank(b)
      if (a.tier !== b.tier) return a.tier === 'high' ? -1 : 1
      return a.onset[0] - b.onset[0]
    })
    .slice(0, 5)
}

// ───────────────────────────────────────────────────────────────────────────
// Levers
// ───────────────────────────────────────────────────────────────────────────

function buildLevers(
  breed: Breed,
  profile: PetProfile,
  bodyCondition: BodyCondition,
  outdoor: OutdoorAccess,
  age: number,
  /** Already resolved against overrides and the zero-delta defaults. */
  dental: DentalRoutine,
  activity: ActivityLevel,
): Lever[] {
  const isCat = breed.species === 'cat'
  const w = (c: BodyCondition) => weightDeltaFor(breed.species, breed.sizeClass, c)
  const taper = outdoorAgeTaper(age)
  const o = (v: OutdoorAccess) => round(OUTDOOR_DELTAS[v] * (OUTDOOR_DELTAS[v] < 0 ? taper : 1), 2)

  return [
    {
      id: 'weight',
      label: 'Body condition',
      question: 'Where does their weight sit?',
      evidenceTier: 'strong',
      evidenceNote: isCat
        ? 'In cats the evidence points the other way to dogs — thin cats carried the clearest risk in the largest study, and mild overweight was not significantly associated with shorter survival.'
        : 'The best-evidenced factor here. Lean-fed dogs in a controlled lifetime study lived a median of 1.8 years longer than their pair-fed littermates, and developed hip arthritis a median of six years later.',
      current: bodyCondition,
      options: [
        {
          value: 'lean',
          label: 'Lean',
          delta: w('lean'),
          note: isCat
            ? 'Below ideal. In cats this is a risk in its own right, not a safety margin.'
            : 'Ribs easily felt, clear waist from above. The condition associated with the longest healthy years.',
        },
        {
          value: 'ideal',
          label: 'Ideal',
          delta: w('ideal'),
          note: 'Ribs felt with light pressure, a visible waist. The target.',
        },
        {
          value: 'overweight',
          label: 'Overweight',
          delta: w('overweight'),
          note: isCat
            ? 'Carries a real cost, though a smaller one than the same picture in a dog.'
            : `Ribs hard to find, waist gone. The effect is largest in small breeds — the opposite of what most people expect.`,
        },
      ],
      citations: LEVER_CITATIONS.weight,
    },
    {
      id: 'dental',
      label: 'Dental care',
      question: 'How often do their teeth get cleaned at home?',
      evidenceTier: 'associational',
      evidenceNote:
        'We weight this one carefully. Periodontal disease is associated with kidney disease in both dogs and cats, but no study shows dental care extends lifespan, and AAHA calls the causal story oversimplified. We move the projection modestly and say so.',
      current: dental,
      options: [
        { value: 'daily', label: 'Daily', delta: DENTAL_DELTAS.daily, note: 'The standard the guidelines describe, and realistic once it is a habit.' },
        { value: 'weekly', label: 'Weekly', delta: DENTAL_DELTAS.weekly, note: 'Better than nothing and a reasonable place to build from.' },
        { value: 'rarely', label: 'Rarely', delta: DENTAL_DELTAS.rarely, note: 'Most dogs and cats seen in practice are diagnosed with dental disease. Rarely is the common answer, not an unusual one.' },
      ],
      citations: LEVER_CITATIONS.dental,
    },
    {
      id: 'activity',
      label: 'Activity',
      question: 'How much do they move on a normal day?',
      evidenceTier: 'directional',
      evidenceNote: isCat
        ? 'No feline lifespan study exists here. We treat activity as a healthspan factor and keep its weight small.'
        : 'The Dog Aging Project found higher activity associated with markedly lower odds of cognitive dysfunction, but the study is cross-sectional and its authors state plainly that causality cannot be determined. So this moves the number gently.',
      current: activity,
      options: [
        { value: 'high', label: 'High', delta: ACTIVITY_DELTAS.high, note: isCat ? 'Hunting play several times a day, climbing, real movement.' : 'Long daily exercise, varied and consistent.' },
        { value: 'moderate', label: 'Moderate', delta: ACTIVITY_DELTAS.moderate, note: isCat ? 'Some daily play, moves around the home freely.' : 'A regular daily walk and some play.' },
        { value: 'low', label: 'Low', delta: ACTIVITY_DELTAS.low, note: isCat ? 'Mostly sleeping and eating, little structured play.' : 'Short or irregular walks, mostly sedentary.' },
      ],
      citations: LEVER_CITATIONS.activity,
    },
    // Cats only. A dog's outdoor time is a walk; a cat's is an unsupervised
    // territory, which is a different question with a different literature.
    ...(isCat
      ? [
          {
            id: 'outdoor' as const,
            label: 'Outdoor access',
            question: 'How much of the world do they get?',
            evidenceTier: 'associational' as const,
            evidenceNote:
              taper < 0.9
                ? `The direction is documented; the size is not what most people assume. The deaths outdoor access adds — traffic above all — are overwhelmingly deaths of young cats, and one necropsy series found no significant difference between indoor, indoor–outdoor and outdoor cats once they had passed their first year. ${profile.name} is past that, so this moves the projection less than it would for a kitten. The magnitude is ours, not a published figure.`
                : 'The direction is documented; the size is not what most people assume. The "outdoor cats live two to five years" line comes from feral colony work and does not describe a cat with a house to come back to. What the owned-cat data shows is that the cost is real and is paid almost entirely in the first few years — median age at death from trauma is 3.0 years against 14.0 across all causes. The magnitude here is ours, not a published figure.',
            current: outdoor,
            options: [
              {
                value: 'indoor',
                label: 'Indoor',
                delta: o('indoor'),
                note: 'Never outside unsupervised. Removes traffic, fights and retrovirus exposure outright — which is a smaller number of years than it sounds, and the surest one.',
              },
              {
                value: 'indoor-outdoor',
                label: 'Both',
                delta: o('indoor-outdoor'),
                note: 'Comes and goes, sleeps at home. This is our reference point, not a penalty — in the one direct comparison we have, these cats did as well as indoor-only ones.',
              },
              {
                value: 'outdoor',
                label: 'Outdoor',
                delta: o('outdoor'),
                note: 'Lives mostly outside, with no reliable indoor base. The group that did clearly worse — and the group whose range we widen, because a farm track and a main road are not the same risk.',
              },
            ],
            citations: LEVER_CITATIONS.outdoor,
          },
        ]
      : []),
  ]
}

// ───────────────────────────────────────────────────────────────────────────
// The engine
// ───────────────────────────────────────────────────────────────────────────

export interface ProjectOptions {
  /** Injected so the function stays pure and testable. */
  now?: Date
  /** Lever overrides from the interactive panel. */
  overrides?: Partial<Pick<PetProfile, 'activity' | 'dental'>> & {
    weight?: BodyCondition
    outdoor?: OutdoorAccess
  }
}

/**
 * project(petProfile) → Projection
 *
 * Pure. Same inputs, same output. No IO, no randomness, no clock unless one is
 * injected via options.now.
 */
export function project(profile: PetProfile, options: ProjectOptions = {}): Projection {
  const now = options.now ?? new Date()
  const breed = findBreed(profile.breedId)
  if (!breed) throw new Error(`Unknown breed: ${profile.breedId}`)

  const age = ageInYears(profile.birthDate, now)
  const declared = new Set(profile.conditionIds)

  // Precedence: an interactive lever override, then a silhouette the owner
  // picked, then the read from their weight. The silhouette outranks the weight
  // because it is a direct observation of this animal, where the weight is an
  // inference from a breed-average range (SPEC §4.2).
  const measured = readBodyCondition(profile.weightLb, breed)
  const picked = bodyConditionFromScore(profile.bodyConditionScore)
  const bodyCondition = options.overrides?.weight ?? picked ?? measured
  // Absent resolves to the engine's own zero-delta reference, so an unanswered
  // question costs nothing and claims nothing. The difference between "not
  // asked" and "answered as the middle" lives on the profile, not here.
  const dental = options.overrides?.dental ?? profile.dental ?? 'weekly'
  const activity = options.overrides?.activity ?? profile.activity ?? 'moderate'
  // Absent means the owner was never asked. The reference costs them nothing,
  // which is the only honest thing to do with a question we did not put.
  const outdoor: OutdoorAccess =
    options.overrides?.outdoor ?? profile.outdoorAccess ?? 'indoor-outdoor'

  // ── Factors ──────────────────────────────────────────────────────────────
  const factors: Projection['factors'] = []
  const push = (label: string, delta: number, note: string, tier: EvidenceTier) => {
    if (delta !== 0) factors.push({ label, delta: round(delta, 2), note, tier })
  }

  const wDelta = weightDeltaFor(breed.species, breed.sizeClass, bodyCondition)
  push(
    bodyCondition === 'ideal' ? 'Body condition — ideal' : `Body condition — ${bodyCondition}`,
    wDelta,
    breed.species === 'cat'
      ? 'Scaled for cats, where the evidence differs from dogs.'
      : `Scaled by size class — the measured effect is largest in the smallest breeds.`,
    'strong',
  )

  push(
    `Dental care — ${dental}`,
    DENTAL_DELTAS[dental] ?? 0,
    'Weighted modestly. The association is documented; the lifespan effect is not.',
    'associational',
  )

  push(
    `Activity — ${activity}`,
    ACTIVITY_DELTAS[activity] ?? 0,
    'Weighted modestly. Supported in direction, not quantified for healthy years.',
    'directional',
  )

  if (breed.species === 'cat') {
    // Tapered: the penalty a free-roaming cat carries is mostly a young-cat
    // penalty, and a cat who has already lived through those years has already
    // survived the risk it describes. The positive for indoor is not tapered —
    // it is a small credit for exposures removed, not for a hazard outrun.
    const raw = OUTDOOR_DELTAS[outdoor] ?? 0
    push(
      `Outdoor access — ${outdoor === 'indoor-outdoor' ? 'indoor and outdoor' : outdoor}`,
      raw < 0 ? raw * outdoorAgeTaper(age) : raw,
      raw < 0
        ? 'Scaled down with age. The mortality outdoor access adds falls overwhelmingly on young cats.'
        : 'A small credit for exposures removed outright, not a published survival difference.',
      'associational',
    )
  }

  if (profile.neutered) {
    push(
      'Neutered',
      NEUTER_DELTA[breed.species],
      'Consistently associated with longer life across large datasets, though the effect is confounded by how neutered and unneutered animals tend to be kept.',
      'associational',
    )
  }

  const rawShift = factors.reduce((sum, f) => sum + f.delta, 0)
  const cap = MAX_SWING[breed.species]
  const shift = clamp(rawShift, cap.down, cap.up)

  // ── Declared conditions: pull the low end, widen the range ────────────────
  const declaredList = KNOWN_CONDITIONS.filter((c) => declared.has(c.id))
  const conditionPenalty = Math.min(
    MAX_CONDITION_PENALTY,
    declaredList.reduce((s, c) => s + c.weight, 0),
  )

  // ── Uncertainty: widen when we know less ─────────────────────────────────
  let widen = 0
  if (breed.confidence === 'illustrative') widen += 0.4
  if (breed.confidence === 'derived') widen += 0.25
  if (breed.isMixed) widen += 0.3
  if (declaredList.length >= 2) widen += 0.3
  if (profile.weightLb <= 0) widen += 0.3
  // Not "we know less about cats outdoors" — we know less about THIS cat's
  // outdoors. A farm track and a main road are the same answer on this form.
  if (breed.species === 'cat' && outdoor === 'outdoor') widen += 0.25
  const widened = widen > 0

  let low = breed.baseline.low + shift - conditionPenalty - widen
  let high = breed.baseline.high + shift - conditionPenalty * 0.35 + widen * 0.5

  // Never invert, never go negative, keep the range readable.
  if (high < low + 1) high = low + 1
  low = Math.max(1, low)
  high = Math.max(low + 1, high)

  // A pet already older than the projection has, in plain terms, beaten the
  // breed average. Lift the whole range rather than only its floor — squashing
  // the floor upward would fake a confidence we do not have, and the width of
  // the range is carrying real information about uncertainty.
  if (age >= low) {
    const lift = age + 0.4 - low
    low += lift
    high += lift
  }

  const healthyYearsRange = { low: round(low, 1), high: round(high, 1) }
  const baselineMid = (breed.baseline.low + breed.baseline.high) / 2
  const stages = buildStages(breed, age, baselineMid, declared)
  const currentStage = stages.find((s) => s.status === 'current') ?? stages[stages.length - 1]

  return {
    healthyYearsRange,
    ageYears: round(age, 1),
    arcPosition: clamp(age / healthyYearsRange.high, 0, 1),
    currentStage,
    stages,
    riskCards: buildRiskCards(breed, age, declared, profile),
    levers: buildLevers(breed, profile, bodyCondition, outdoor, age, dental, activity),
    breed,
    factors,
    widened,
    bodyCondition,
    weightRead: picked
      ? weightNote(picked, breed, profile.weightLb, true)
      : weightNote(measured, breed, profile.weightLb, false),
  }
}

export { EVIDENCE_LABELS }
