/**
 * The Data Covenant — invariant 5, and SPEC §6.10 ("content to get right").
 *
 * ── LEGAL-REVIEW ───────────────────────────────────────────────────────────
 * This makes binding-sounding promises about how data may be used, and the
 * premium clause touches insurance regulation directly. It needs counsel before
 * launch. What they need to rule on, rather than what we have decided:
 *
 *  1. Whether "never used against an individual claim" as written creates an
 *     enforceable commitment, and whether we want it to. We do — that is the
 *     point — but it should be deliberate and it should survive an MGU
 *     agreement that may say otherwise.
 *  2. The filed-program carve-out. A rated program using device data would be a
 *     filed, transparent, opt-in product; the wording must make clear that it
 *     is a separate thing an owner chooses, not a door left ajar in this one.
 *  3. Whether this page needs to be, or should avoid being, part of the formal
 *     privacy policy. It is deliberately not written as one.
 *  4. Data-subject rights wording against the states we will operate in.
 * ───────────────────────────────────────────────────────────────────────────
 *
 * Content lives here rather than in JSX so it can be read in one place, diffed
 * when it changes, and tested. The tests assert the promises invariants 4 and 5
 * actually require are present — this is exactly the copy that drifts.
 *
 * Vocabulary per docs/VISION.md: never "lifecycle", "platform" or standalone
 * "wellness"; never promise a longer life.
 */

export interface CovenantSection {
  id: string
  heading: string
  /** Paragraphs. Plain words — this is not the privacy policy. */
  body: string[]
  /** Optional hard promises, rendered as a list. */
  promises?: string[]
}

export const COVENANT_TITLE = 'The Data Covenant'

export const COVENANT_INTRO =
  'Clovara knows things about your pet that could be used against you. This page is our promise about what we will never do with them, written before we had any reason to need it.'

export const COVENANT: CovenantSection[] = [
  {
    id: 'what-we-hold',
    heading: 'What we hold',
    body: [
      "What you have told us: the breed, the birthday, the weight, anything already diagnosed, how the days go. What a tracker sends, if you ever wear one on them. What you and the companion have talked about.",
      'That is a real picture of an animal, and it is the reason the plan is any good. It is also, in the wrong hands, a list of reasons to charge someone more.',
    ],
  },
  {
    id: 'never',
    heading: 'What it is never used for',
    body: [
      'These are the ones that matter, so they are first and they are plain.',
    ],
    promises: [
      'Nothing you tell the companion is used to decide a claim. Not to question one, not to delay one, not to deny one.',
      'Nothing a tracker records is used to decide a claim either. A quiet week is not evidence of anything.',
      'Your data does not change your premium. Not up, and not down as a reward for behaving — which is the same promise, and it is the one that keeps the first two honest.',
      'We do not sell it. Not to brokers, not to advertisers, not to anyone building a model to price people.',
    ],
  },
  {
    id: 'companion',
    heading: 'The companion is firewalled',
    body: [
      "It helps you notice things and tells you when to call a vet. It does not diagnose, it does not prescribe, and it is not a route into underwriting or claims — the people and systems that decide those never see the conversation.",
      'That separation is deliberate. A companion you are careful in front of is useless, and one you are honest with only works if honesty is free.',
    ],
  },
  {
    id: 'aggregate',
    heading: 'What it does get used for',
    body: [
      'Your pet, first. Everything here exists to make their plan sharper and their care easier.',
      'And, in aggregate, the science. Pooled across thousands of animals with nothing identifying in it, this data can answer questions the published literature currently cannot — which is how a breed moves from an illustrative figure to a real one. Nothing in that work traces back to a name, an address, or a policy.',
    ],
  },
  {
    id: 'exception',
    heading: 'The one exception, stated plainly',
    body: [
      'A rated programme — where a tracker genuinely earns someone a different price — is a thing insurers do, and one day we may offer it. If we ever do, it will be a separate product you choose on purpose: filed with the regulator, priced transparently, explained before you opt in, and leavable.',
      'It will never be this. Joining Clovara does not enrol you in it, and no data you have already given us would be used to price you under it without you saying yes first.',
    ],
  },
  {
    id: 'control',
    heading: 'What you can do about it',
    body: [
      'Ask us for everything we hold on your pet and we will send it in a form you can actually read. Ask us to delete it and we will, including from the aggregate work where it has not already been anonymised beyond recovery.',
      'You do not have to give a reason, and asking does not affect your membership or any policy.',
    ],
  },
  {
    id: 'changes',
    heading: 'If this ever changes',
    body: [
      'A promise you can quietly edit is not a promise. If we change anything on this page we will say so directly — not in a version note — and the old wording will stay readable beside the new one.',
    ],
  },
]

/** One line for the places that link here. */
export const COVENANT_TEASER =
  'What we do and never do with what you tell us.'
