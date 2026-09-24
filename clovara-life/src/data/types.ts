/**
 * Clovara Life — core data types.
 *
 * Everything the projection engine reads is typed here. The engine itself is a
 * pure function; these types are the whole of its input contract.
 */

export type Species = 'dog' | 'cat'

/** Size classes follow the Banfield/Montoya 2023 life-table bands. */
export type SizeClass = 'toy' | 'small' | 'medium' | 'large' | 'giant'

/**
 * How much we trust a figure.
 *
 * - `published`  — the authored range brackets a directly published figure for
 *                  this breed, cited in `evidence`.
 * - `derived`    — composed from two or more published figures by an explicit,
 *                  documented calculation (e.g. AAHA's "last 25% of lifespan"
 *                  senior rule applied to a published life-expectancy figure).
 * - `illustrative` — no breed-level published figure was found. The range is
 *                  anchored to the published size-class life expectancy and set
 *                  by clinical convention. FIRM THIS UP before any claim is made
 *                  on it. Surfaced in the app's methodology panel.
 */
export type Confidence = 'published' | 'derived' | 'illustrative'

/**
 * Strength of the evidence behind a modifiable factor. Drives the honesty badge
 * shown next to each lever — we never present all three as equally proven.
 */
export type EvidenceTier = 'strong' | 'associational' | 'directional'

export type RiskTier = 'high' | 'moderate'

export interface Citation {
  /** Short human-readable citation, e.g. "McMillan et al. 2024, Sci Rep". */
  label: string
  url?: string
  /** What the figure actually measures. Metrics are NOT interchangeable. */
  metric?: string
  /** The published number this entry was anchored to, if there is one. */
  figure?: string
}

export interface BreedCondition {
  id: string
  name: string
  /** Age window, in years, where this typically becomes worth watching for. */
  onset: [number, number]
  tier: RiskTier
  /** Plain-language sign the owner might notice. */
  watch: string
  /** What to actually do about it. Never a diagnosis or a prescription. */
  action: string
  confidence: Confidence
  evidence?: Citation[]
}

export interface Breed {
  id: string
  name: string
  species: Species
  sizeClass: SizeClass
  /** Extra search terms for the autocomplete. */
  aliases?: string[]
  /**
   * Authored healthy-years baseline for a pet of this breed at ideal weight,
   * average care. This is the range BEFORE any lifestyle adjustment.
   * See METHODOLOGY in engine.ts for how these were set.
   */
  baseline: { low: number; high: number }
  /** Typical adult weight in pounds. Used for the body-condition read. */
  weight: { low: number; high: number }
  conditions: BreedCondition[]
  confidence: Confidence
  evidence: Citation[]
  /** Shown in the methodology panel where it adds honesty. */
  note?: string
  /** True for the size-class fallbacks used by "Mixed / not sure". */
  isMixed?: boolean
}

/** An owner-declarable existing condition, offered in onboarding. */
export interface KnownCondition {
  id: string
  name: string
  species: Species[]
  /** Nudges the low end of the range down by this many years, capped by engine. */
  weight: number
  /** How this reframes the care plan once it is already present. */
  managing: string
}

export type BodyCondition = 'lean' | 'ideal' | 'overweight'

/**
 * A 5-point body-condition score, as picked from silhouettes (SPEC §4.2).
 *
 * Five because that is how body condition is actually assessed and how an owner
 * can recognise their own animal. Three because that is all the engine has
 * evidence for — Salt 2019 and Teng 2018 compare overweight/thin against a
 * normal reference, not a five-band curve. So the picker collects five and
 * `bodyConditionFromScore` maps them onto the three the engine can defend.
 * Keeping the 5 means "a bit thin" and "very thin" stay distinguishable for the
 * care copy without pretending the projection can tell them apart.
 */
export type BodyConditionScore = 1 | 2 | 3 | 4 | 5
export type DentalRoutine = 'daily' | 'weekly' | 'rarely'
export type ActivityLevel = 'low' | 'moderate' | 'high'
export type DietQuality = 'measured' | 'free-fed' | 'unsure'
export type Sex = 'male' | 'female'

/**
 * How much of the world a cat has access to. Asked for cats only; the engine
 * ignores it on a dog.
 *
 * `indoor-outdoor` is the REFERENCE, not `indoor`. Two reasons. The populations
 * the breed baselines are read from are mixed, UK-heavy and largely outdoor-
 * access. And the one direct comparison we have (Kent 2022) put indoor–outdoor
 * cats level with indoor-only ones. See OUTDOOR_DELTAS in engine.ts.
 */
export type OutdoorAccess = 'indoor' | 'indoor-outdoor' | 'outdoor'

/**
 * Age band at neutering, in Hart 2020's own bands.
 *
 * Recorded for dogs and used ONLY to frame joint-disorder risk on the care
 * cards. It is deliberately not a lifespan adjustment: Hart reports joint
 * disorder incidence, not survival, and reading a number of years off it would
 * be inventing one. It is also not actionable — nobody can re-time a neuter
 * that already happened — so it belongs in "what to watch for", never in the
 * projection.
 */
export type NeuterAgeBand = 'under-6m' | '6-11m' | '12-23m' | '24m-plus' | 'unsure'

export interface PetProfile {
  id: string
  name: string
  species: Species
  breedId: string
  /** ISO date string. */
  birthDate: string
  /**
   * The birthday was estimated from an "about N years old" answer rather than
   * known. SPEC §4.1 offers both, and they are different claims — a rescue
   * whose age was guessed at the shelter is not the same as a puppy with
   * papers. Nothing in the engine reads it yet; it exists so the distinction
   * survives being written down.
   */
  birthDateApprox?: boolean
  sex: Sex
  /**
   * Optional since SPEC §4.1 moved this out of Tier 0 — the reveal happens
   * before anyone is asked. Absent means "not told yet", which the engine
   * treats as no adjustment either way, NOT as intact. `false` is a real answer
   * that someone gave.
   */
  neutered?: boolean
  /**
   * Optional, dogs only. Absent means the owner was not asked or did not know,
   * and nothing is inferred from that. Never affects the projection.
   */
  neuterAgeBand?: NeuterAgeBand
  weightLb: number
  /**
   * Set when the owner picked a silhouette. Takes precedence over the weight
   * read, because it is a direct observation of the animal rather than an
   * inference from a number against a breed-average range — which is exactly
   * why SPEC §4.2 says never to ask for kg first.
   */
  bodyConditionScore?: BodyConditionScore
  conditionIds: string[]
  /**
   * Tier 1, so all optional (SPEC §4.1/§4.2). Absent means nobody has been
   * asked — which is NOT the same as the middle setting, even though the engine
   * treats both as no adjustment. The accuracy meter needs to tell them apart
   * or it would claim to know the daily routine of a pet whose owner has
   * answered five questions.
   */
  activity?: ActivityLevel
  dental?: DentalRoutine
  diet?: DietQuality
  /**
   * Optional, cats only. Absent is treated as the reference (`indoor-outdoor`),
   * so a pet saved before this field existed keeps the number its owner already
   * saw rather than having an answer guessed for it.
   */
  outdoorAccess?: OutdoorAccess
  /** Set only on the seeded demo pets. */
  demo?: boolean
  /**
   * Their photo. `avatarUrl` is what every surface renders; `fullPath` is the
   * copy kept for a future body-condition trend (SPEC §4.2).
   *
   * Worth nothing to the accuracy meter on purpose — it is the most satisfying
   * thing an owner can add and it sharpens the projection not at all.
   */
  photo?: {
    fullPath: string
    avatarPath: string
    avatarUrl: string
    uploadedAt: string
    width: number
    height: number
  }
  /** Optional colour-of-story detail shown on the journey. */
  headline?: string
  /**
   * When we first knew this pet, and when they were last reviewed (SPEC §4.3's
   * annual re-projection).
   *
   * `knownSince` is separate from `birthDate` on purpose: a nine-year-old
   * rescue adopted last week has been ours for a week, and anchoring the yearly
   * review on their birthday would put a "what changed this year?" in front of
   * someone who has not had them for a year. Both absent means no review is
   * due, which is the safe direction.
   */
  knownSince?: string
  lastReviewedAt?: string
  /**
   * Socialization Passport stamps collected (SPEC §6.3), by stamp id.
   *
   * Ids rather than labels so the copy can be rewritten without rewriting
   * everybody's history, and a set rather than counts because SPEC asks for
   * qualitative marks only — "they met this and it was fine", never how often.
   */
  socialStamps?: string[]
  /**
   * What the owner says was given, and when (SPEC §6.4).
   *
   * Their note to themselves. Not a medical record, never sent anywhere, and
   * explicitly not evidence of anything — the absence of an entry means nobody
   * typed it in, which is not the same as a dose not given.
   */
  vaccineRecords?: { doseId: string; givenOn: string }[]
  /**
   * What somebody minding them needs to know (SPEC §6.6).
   *
   * Deliberately free text and deliberately small. This is a fridge note, not
   * a medical record: it is the only thing in the product that leaves the
   * household on an unauthenticated link, so nothing that belongs in the
   * Health File belongs here.
   */
  /**
   * What they take (SPEC-HORIZON §1.4). The owner's note of what they were
   * told; never checked, never interpreted, and carrying no record of who
   * logged a dose.
   */
  medications?: {
    id: string
    name: string
    amount: string
    frequency: string
    startedOn: string
    quantity?: number
    given: string[]
  }[]
  /**
   * When they died, if an owner has told us (SPEC-HORIZON §2.5).
   *
   * Setting it silences every prompt, reminder, offer and question in the
   * product. It never deletes anything.
   */
  diedOn?: string
  /**
   * The lump diary (SPEC-HORIZON §1.1).
   *
   * On the pet document rather than a subcollection: the rules deny every
   * `{sub=**}` under a pet pending the Firestore security review, and a diary
   * of photographs an owner took of their own animal does not need to wait for
   * that review the way vet records do.
   */
  lumps?: {
    id: string
    location: string
    firstSeen: string
    note?: string
    photos: {
      url: string
      fullPath: string
      takenAt: string
      sizeReference: string | null
    }[]
  }[]
  careNotes?: {
    feeding?: string
    meds?: string
    quirks?: string
    vetName?: string
    vetPhone?: string
    emergencyName?: string
    emergencyPhone?: string
  }
  /**
   * The healthy-years range as it stood at the last review.
   *
   * Two numbers, stored so that next year's review can say what we said last
   * year. Without it the "annual re-projection" is only a data refresh — there
   * is nothing to re-project against, because today's profile cannot tell us
   * what we believed twelve months ago.
   */
  lastReviewedRange?: { low: number; high: number }
  /**
   * The owner has seen the conditions list and made a choice — including
   * choosing none.
   *
   * Without this, "no conditions declared" and "never asked" are the same empty
   * array, and the accuracy meter would nag forever at someone whose pet is
   * simply healthy. Invariant 9 makes "none that I know of" a real answer, and
   * this is what records that it was given.
   */
  conditionsReviewed?: boolean
}

export interface LifeStage {
  id: string
  label: string
  /** Age band in years. `to` is null for the final stage. */
  from: number
  to: number | null
  status: 'past' | 'current' | 'future'
  /** One line on what this stage is about. */
  summary: string
  recommendations: string[]
}

export interface RiskCard {
  id: string
  name: string
  onset: [number, number]
  tier: RiskTier
  watch: string
  action: string
  /** 'watch' before the window and with no diagnosis; 'manage' once declared. */
  mode: 'watch' | 'manage' | 'active'
  window: string
  confidence: Confidence
  /**
   * Framing that comes from this animal rather than from the breed — currently
   * only age at neutering against joint disorders. Always qualitative, always
   * carries the study it comes from, and never moves the projection.
   */
  context?: { text: string; source: Citation }
}

export interface LeverOption {
  value: string
  label: string
  /** Years added or removed from the projection. */
  delta: number
  /** Short plain-language note. Never states an invented statistic. */
  note: string
}

export interface Lever {
  id: 'weight' | 'dental' | 'activity' | 'outdoor'
  label: string
  question: string
  evidenceTier: EvidenceTier
  /** One line on how strong the evidence actually is. Shown in the UI. */
  evidenceNote: string
  current: string
  options: LeverOption[]
  citations: Citation[]
}

export interface Projection {
  healthyYearsRange: { low: number; high: number }
  ageYears: number
  /** 0–1 position along the life arc. */
  arcPosition: number
  currentStage: LifeStage
  stages: LifeStage[]
  riskCards: RiskCard[]
  levers: Lever[]
  breed: Breed
  /** Human-readable list of what moved the number, for the "why" panel. */
  factors: { label: string; delta: number; note: string; tier: EvidenceTier }[]
  /** True when inputs were sparse and we widened the range in response. */
  widened: boolean
  bodyCondition: BodyCondition
  weightRead: string
}
