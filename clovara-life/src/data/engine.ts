/**
 * ═══════════════════════════════════════════════════════════════════════════
 * CLOVARA LIFE — ENGINE DATA
 * ═══════════════════════════════════════════════════════════════════════════
 *
 * This is the reviewable file. Everything the projection engine knows lives
 * here or in the modules it re-exports. The engine itself (src/engine/project.ts)
 * is a pure function with no data of its own.
 *
 * ───────────────────────────────────────────────────────────────────────────
 * METHODOLOGY
 * ───────────────────────────────────────────────────────────────────────────
 *
 * WHAT WE PROJECT
 * "Healthy years" is not lifespan. It is our estimate of the years a pet is
 * likely to spend in good health — before chronic disease becomes the thing
 * that shapes their days. It is always shown as a range, never a point, and
 * always with "on track for" framing. We do not project a date of death and
 * the product never uses that language.
 *
 * HOW THE BASELINE RANGE IS SET
 * Each breed carries an authored `baseline: {low, high}`. It is set by reading
 * the published figure or figures for that breed and placing a range around
 * them, with three things adjusted for:
 *
 *   1. METRIC. The large studies do not measure the same thing. "Life
 *      expectancy at age 0" (Teng 2022, Teng 2024, Montoya 2023) includes
 *      animals that die as puppies and kittens, so it runs systematically below
 *      "median survival" (McMillan 2024) or "median age at death" (O'Neill
 *      2015). Figures from different studies are never averaged. Where a breed
 *      has figures from more than one, both are listed in `evidence` with their
 *      metric attached and the range is set against the one that best matches
 *      the question an owner is actually asking — how long is the animal in
 *      front of me likely to be well.
 *
 *   2. POPULATION. The two largest breed-level studies are UK. The largest US
 *      dataset (Montoya 2023, 13.3M dogs and 2.4M cats at Banfield practices)
 *      reports only by size class, so it anchors the size-class fallbacks and
 *      is used as a sense-check on the UK breed figures.
 *
 *   3. THE END-OF-LIFE ALLOWANCE. Healthy years sit below total lifespan.
 *
 * Every breed carries a `confidence`:
 *   published    — a breed-level figure exists in the cited study.
 *   derived      — a figure exists but does not transfer directly; the range is
 *                  composed from it plus the size-class figure, with the
 *                  reasoning written out in `note`.
 *   illustrative — no breed-level published figure was found. Anchored to the
 *                  size-class figure and clinical convention. These are listed
 *                  in the app's methodology panel so nobody mistakes them for
 *                  literature. They are the list to firm up first.
 *
 * We never invent a citation. Where the honest answer was "this figure is not
 * published", the entry says so rather than filling the gap.
 *
 * HOW THE ADJUSTMENTS WORK
 * The projection is the baseline range shifted by a small number of factors,
 * each with an evidence tier that is shown in the interface:
 *
 *   strong        — a quantified effect from a controlled or large cohort
 *                   study. Body condition in dogs is the only factor at this
 *                   tier. The Purina lifetime feeding study found lean-fed
 *                   Labradors lived a median of 13.0 years against 11.2 for
 *                   their pair-fed controls, and a 50,787-dog US study found
 *                   overweight body condition associated with shorter lifespan
 *                   in all twelve breeds examined — most strongly in SMALL
 *                   breeds, which is the opposite of what most people assume.
 *
 *   associational — a documented association where causation is not
 *                   established. Dental care and neuter status sit here.
 *                   Critically: there is NO published lifespan effect of dental
 *                   care in dogs or cats. What exists is an association between
 *                   periodontal disease and kidney disease, and AAHA's own
 *                   guidelines call the causal story "oversimplified and
 *                   difficult to prove". The dental lever therefore moves the
 *                   projection modestly and the interface says plainly that the
 *                   evidence is associational.
 *
 *   directional   — supported in direction but not quantified for lifespan.
 *                   Activity sits here. The Dog Aging Project found higher
 *                   physical activity associated with lower odds of cognitive
 *                   dysfunction, cross-sectionally, and the authors explicitly
 *                   state causality cannot be determined. No lifespan study
 *                   exists.
 *
 * CATS ARE NOT SMALL DOGS
 * The body-condition factor is deliberately different by species. In dogs,
 * overweight is the clear risk. In cats, a study of 2,609 animals found THIN
 * cats at clearly higher risk of death and cats at body condition 7–8 not
 * significantly different from the reference — only the most obese group was.
 * So "lean" is a positive in a dog and a mild negative in a cat, and the engine
 * reflects that rather than porting dog logic across.
 *
 * UNCERTAINTY HONESTY
 * The range widens when we know less: an illustrative breed baseline, a mixed
 * breed, a pet whose weight sits far outside the breed's typical adult range.
 * Declared existing conditions pull the low end down and widen the range rather
 * than simply subtracting years. Total adjustment is capped so the output stays
 * plausible whatever combination of inputs is given.
 *
 * KNOWN LIMITATIONS
 * - Indoor versus outdoor living is one of the largest determinants of feline
 *   life expectancy and this version does not ask about it.
 * - Age at neutering matters for joint disease in dogs over roughly 45 lb, and
 *   this version records neuter status but not the age it happened.
 * - All breed data is breed-average. It says nothing about an individual
 *   animal's genetics.
 *
 * ═══════════════════════════════════════════════════════════════════════════
 */

import type { Breed, EvidenceTier, Species, SizeClass, Citation } from './types'
import { DOG_BREEDS } from './breeds.dogs'
import { CAT_BREEDS } from './breeds.cats'
import {
  KEALY_2002,
  LAWLER_2008,
  SALT_2019,
  SMITH_2006,
  TENG_BCS_2018,
  AAHA_DENTAL_2019,
  GLICKMAN_2011,
  TREVEJO_2018,
  BANFIELD_DENTAL_2024,
  BRAY_2023,
  HOFFMAN_2013,
  AAHA_CANINE_2019,
  AAHA_FELINE_2021,
  AAHA_SENIOR_2023,
  APOP_2022,
} from './sources'

export * from './types'
export { KNOWN_CONDITIONS, conditionsFor } from './conditions'
export { DOG_BREEDS } from './breeds.dogs'
export { CAT_BREEDS } from './breeds.cats'

export const ALL_BREEDS: Breed[] = [...DOG_BREEDS, ...CAT_BREEDS]

export function breedsFor(species: Species): Breed[] {
  return ALL_BREEDS.filter((b) => b.species === species)
}

export function findBreed(id: string): Breed | undefined {
  return ALL_BREEDS.find((b) => b.id === id)
}

/** Size-class fallbacks used when the owner picks "Mixed / not sure". */
export const MIXED_BY_SIZE: Record<SizeClass, string> = {
  toy: 'mixed-toy',
  small: 'mixed-small',
  medium: 'mixed-medium',
  large: 'mixed-large',
  giant: 'mixed-giant',
}

export const SIZE_LABELS: { value: SizeClass; label: string; hint: string }[] = [
  { value: 'toy', label: 'Toy', hint: 'under 12 lb' },
  { value: 'small', label: 'Small', hint: '12–25 lb' },
  { value: 'medium', label: 'Medium', hint: '25–55 lb' },
  { value: 'large', label: 'Large', hint: '55–90 lb' },
  { value: 'giant', label: 'Giant', hint: 'over 90 lb' },
]

// ───────────────────────────────────────────────────────────────────────────
// ADJUSTMENT MODEL
// ───────────────────────────────────────────────────────────────────────────

/**
 * Body condition. Dogs and cats are handled separately and deliberately.
 *
 * Dogs: the overweight penalty is scaled by size class, following Salt 2019,
 * which found the largest median lifespan differences in the SMALLEST breeds
 * (Yorkshire Terrier −2.5 years) and the smallest in the largest (German
 * Shepherd −0.4 years).
 *
 * Cats: Teng 2018 found thin cats at markedly higher risk and cats at body
 * condition 7–8 not significantly different from the reference group. Only the
 * most obese group showed a clear association. So the shape of the curve is
 * different, and "lean" is not a bonus.
 */
export const WEIGHT_DELTAS: Record<Species, Partial<Record<SizeClass, { lean: number; ideal: number; overweight: number }>> & { default: { lean: number; ideal: number; overweight: number } }> = {
  dog: {
    toy: { lean: 0.5, ideal: 0, overweight: -2.0 },
    small: { lean: 0.5, ideal: 0, overweight: -1.9 },
    medium: { lean: 0.4, ideal: 0, overweight: -1.5 },
    large: { lean: 0.3, ideal: 0, overweight: -1.0 },
    giant: { lean: 0.3, ideal: 0, overweight: -0.9 },
    default: { lean: 0.4, ideal: 0, overweight: -1.5 },
  },
  cat: {
    default: { lean: -0.5, ideal: 0, overweight: -0.7 },
  },
}

export const DENTAL_DELTAS: Record<string, number> = {
  daily: 0.35,
  weekly: 0,
  rarely: -0.5,
}

export const ACTIVITY_DELTAS: Record<string, number> = {
  high: 0.4,
  moderate: 0,
  low: -0.5,
}

export const NEUTER_DELTA: Record<Species, number> = { dog: 0.4, cat: 0.6 }

/** Maximum the projection may move in either direction, in years. */
export const MAX_SWING = { down: -2.6, up: 1.4 }

/** Maximum the declared-conditions penalty may pull the low end down. */
export const MAX_CONDITION_PENALTY = 1.8

export const EVIDENCE_LABELS: Record<EvidenceTier, { label: string; blurb: string }> = {
  strong: {
    label: 'Strong evidence',
    blurb: 'Quantified in controlled and large cohort studies.',
  },
  associational: {
    label: 'Associational',
    blurb: 'A documented association. Causation is not established.',
  },
  directional: {
    label: 'Directional',
    blurb: 'Supported in direction, not quantified for healthy years.',
  },
}

export const LEVER_CITATIONS: Record<'weight' | 'dental' | 'activity', Citation[]> = {
  weight: [KEALY_2002, LAWLER_2008, SMITH_2006, SALT_2019, TENG_BCS_2018, APOP_2022],
  dental: [AAHA_DENTAL_2019, GLICKMAN_2011, TREVEJO_2018, BANFIELD_DENTAL_2024],
  activity: [BRAY_2023],
}

export const NEUTER_CITATIONS: Citation[] = [HOFFMAN_2013]

export const STAGE_CITATIONS: Citation[] = [AAHA_CANINE_2019, AAHA_FELINE_2021, AAHA_SENIOR_2023]

// ───────────────────────────────────────────────────────────────────────────
// LIFE STAGES
// ───────────────────────────────────────────────────────────────────────────

/**
 * Dog life stages follow the AAHA 2019 definitions. Note the structural point:
 * AAHA defines senior PROPORTIONALLY — "the last 25% of estimated lifespan" —
 * not as a fixed age. So senior arrives at seven for a giant breed and eleven
 * for a toy breed, computed from that breed's own baseline.
 *
 * Cat life stages follow the AAHA/AAFP 2021 definitions, which use FIXED ages:
 * kitten under 1, young adult 1–6, mature adult 7–10, senior over 10. That
 * asymmetry between species is in the guidelines, not an inconsistency here.
 *
 * The `puppyEnd` and `youngAdultEnd` values below are set within AAHA's stated
 * windows ("cessation of rapid growth, around 6–9 months, varying with breed
 * and size"; "physical and social maturation, in most dogs by 3 to 4 years"),
 * scaled by size class. That scaling is our interpretation, not a published
 * table.
 */
export const DOG_STAGE_BOUNDS: Record<SizeClass, { puppyEnd: number; youngAdultEnd: number }> = {
  toy: { puppyEnd: 0.6, youngAdultEnd: 3.5 },
  small: { puppyEnd: 0.7, youngAdultEnd: 3.5 },
  medium: { puppyEnd: 0.9, youngAdultEnd: 3.5 },
  large: { puppyEnd: 1.2, youngAdultEnd: 3.0 },
  giant: { puppyEnd: 1.5, youngAdultEnd: 2.5 },
}

export const CAT_STAGE_BOUNDS = { kittenEnd: 1, youngAdultEnd: 7, matureAdultEnd: 10 }

interface StageTemplate {
  id: string
  label: string
  summary: string
  care: string[]
}

export const DOG_STAGE_TEMPLATES: Record<string, StageTemplate> = {
  puppy: {
    id: 'puppy',
    label: 'Puppy',
    summary: 'Growth, vaccination and the habits that will still be paying off in ten years.',
    care: [
      'Finish the vaccination and parasite schedule, and get a full physical exam at each visit.',
      'Start toothbrushing once the adult teeth are through — the habit is far easier to build now than later.',
      'Socialise deliberately and early; behaviour problems are a leading reason dogs lose their homes.',
      'Agree a neutering plan with your vet rather than a default date. In larger dogs, timing is associated with joint disorder risk.',
    ],
  },
  'young-adult': {
    id: 'young-adult',
    label: 'Young adult',
    summary: 'Peak physical condition. This is where the baseline gets set for everything after.',
    care: [
      'A physical exam every six to twelve months, and establish baseline bloodwork while everything is normal.',
      'Lock in the adult body condition now. What is normal at three tends to persist.',
      'First professional dental cleaning and charting, especially in small breeds and where teeth are crowded.',
      'Keep exercise regular rather than weekend-heavy — steady conditioning protects joints.',
    ],
  },
  'mature-adult': {
    id: 'mature-adult',
    label: 'Mature adult',
    summary: 'The quiet middle. Things start appearing on bloodwork before they appear at home.',
    care: [
      'Annual exam with a full blood panel and urinalysis — the point is to catch drift, not disease.',
      'Weigh at every visit and write it down. Slow gain is nearly invisible month to month.',
      'Keep dental care going; this is when neglected mouths start showing consequences.',
      'Note any change in stamina, stiffness or sleep. Owners spot these long before a vet can.',
    ],
  },
  senior: {
    id: 'senior',
    label: 'Senior',
    summary: 'Comfort, closer watching, and treating "slowing down" as a question rather than an answer.',
    care: [
      'Move to exams every six months, with bloodwork and urinalysis at least annually and often twice yearly.',
      'Add blood pressure and thyroid testing to the senior panel.',
      'Treat stiffness as treatable pain rather than simply age — arthritis is under-recognised and manageable.',
      'Adapt the home: traction on smooth floors, ramps instead of jumps, a warmer and softer bed.',
      'Watch for cognitive change — night-time restlessness, staring, getting stuck in corners.',
    ],
  },
}

export const CAT_STAGE_TEMPLATES: Record<string, StageTemplate> = {
  kitten: {
    id: 'kitten',
    label: 'Kitten',
    summary: 'Under one year. Vaccination, parasite control, and getting handling right for life.',
    care: [
      'Complete the vaccination and parasite schedule; retrovirus testing is strongly recommended at this stage.',
      'Get your cat used to having its mouth, ears and paws handled. It pays back at every future vet visit.',
      'Start toothbrushing early — a cat that accepts it as a kitten will usually accept it for life.',
      'Introduce the carrier as furniture rather than as a warning sign.',
    ],
  },
  'young-adult': {
    id: 'young-adult',
    label: 'Young adult',
    summary: 'One to six years. Outwardly the quietest stretch, which is exactly why the baseline matters.',
    care: [
      'An exam at least once a year, even when nothing seems wrong. Cats conceal illness well.',
      'Establish baseline bloodwork and weight while your cat is healthy — the comparison is what makes later results readable.',
      'Hold weight steady. Weight gain between two and six is the most common preventable problem in cats.',
      'Structured play twice a day. It is the closest thing to an exercise prescription a cat will accept.',
    ],
  },
  'mature-adult': {
    id: 'mature-adult',
    label: 'Mature adult',
    summary: 'Seven to ten years. The stage where testing starts to earn its keep.',
    care: [
      'Annual exam with bloodwork and urinalysis. Thyroid testing is worth considering from this stage.',
      'Weigh at every visit. Unexplained weight loss in a cat this age is a finding, not a coincidence.',
      'Full oral assessment — dental disease is the most commonly diagnosed problem in cats in primary care.',
      'Note any change in jumping, grooming or litter-box habits. These are usually the first signs of arthritis.',
    ],
  },
  senior: {
    id: 'senior',
    label: 'Senior',
    summary: 'Over ten. Twice-yearly checks, and reading behaviour change as information.',
    care: [
      'Exams at least every six months, with bloodwork, urinalysis, thyroid level and blood pressure.',
      'Kidney values and urine concentration together — one without the other misses early disease.',
      'Make the home easier: low-sided litter trays, steps to favourite perches, warm and accessible beds.',
      'A cat that stops grooming, stops jumping, or starts yowling at night is telling you something specific.',
    ],
  },
}
