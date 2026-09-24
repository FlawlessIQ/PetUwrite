/**
 * The safety classifier (SPEC-COMPANION §3.1).
 *
 * Deterministic, model-free, and first in the pipeline. A model must never be
 * the thing standing between somebody and an escalation message: a classifier
 * that is sometimes slow, sometimes down and occasionally creative is not
 * acceptable in that position. Substring matching is worse at nuance and better
 * at being there.
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * NEGATION IS DELIBERATELY NOT HANDLED, AND THIS IS THE OPPOSITE OF THE
 * CONVERSATIONAL PARSER.
 *
 * In `extract/conversational.ts`, a negation must never create a fact: reading
 * "no history of seizures" as a seizure history puts a fabricated diagnosis on
 * an animal's record. So that parser suppresses on negation.
 *
 * Here, suppressing on negation would mean "he is not breathing right" fails to
 * escalate. The same machinery that correctly drops "no seizures" would drop
 * "no, seizure!" and "not breathing". Both directions bias towards the safe
 * error, and the safe error is the opposite one in each place.
 *
 * The cost is a false escalation for somebody who typed "she has never had a
 * seizure". That is a wasted phone call, and the copy is written so it reads as
 * a check rather than an alarm.
 * ═══════════════════════════════════════════════════════════════════════════
 *
 * Pure.
 */
import { RED_FLAGS, type RedFlag } from '../data/redFlags'
import type { Species } from '../data/types'

export interface SafetyResult {
  escalate: boolean
  matched: RedFlag[]
  /** Everything we looked at, for the "what we checked" line. */
  consideredCount: number
}

/** Loose normalisation. Punctuation goes; apostrophes are kept both ways. */
function normalise(text: string): string {
  return text
    .toLowerCase()
    .replace(/[’']/g, "'")
    .replace(/[^a-z0-9' ]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

export function classify(utterance: string, species: Species): SafetyResult {
  const said = normalise(utterance)
  const forSpecies = RED_FLAGS.filter((f) => !f.species || f.species === species)
  if (!said) return { escalate: false, matched: [], consideredCount: forSpecies.length }

  const matched = forSpecies.filter((f) =>
    f.phrases.some((p) => said.includes(normalise(p))),
  )
  return { escalate: matched.length > 0, matched, consideredCount: forSpecies.length }
}

/**
 * Everything the classifier watches for, for the page that lists it.
 *
 * Showing the list is part of the honesty: an owner who can see what we check
 * for can see what we do not, which is the only way "nothing matched" means
 * anything.
 */
export function flagsFor(species: Species): RedFlag[] {
  return RED_FLAGS.filter((f) => !f.species || f.species === species)
}
