/**
 * When a pet has died (SPEC-HORIZON §2.5, the defensive pass).
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * THIS IS NOT THE REMEMBER CHAPTER. That needs a document written slowly by
 * somebody who has thought about grief rather than features, and it is not
 * this. This is the defensive half: making certain that when somebody tells us
 * their animal has died, everything we built stops talking.
 *
 * FOUR FAILURES SHIP IN REAL PRODUCTS TODAY, and every one is the result of
 * nobody owning the end of the relationship:
 *
 *   - a renewal notice for a dead animal
 *   - a reminder that a vaccination is due
 *   - a recommendation to buy something
 *   - a cheerful daily briefing about how they are doing
 *
 * Each arrives weeks later, from a system that was never told to stop, and
 * each is remembered for years.
 *
 * THE ENFORCEMENT IS CENTRAL, NOT PER-SURFACE. Gating fifteen components by
 * remembering to check in each one guarantees the sixteenth is missed, and the
 * sixteenth is the one that sends the email. So the ENGINES go quiet: a
 * remembered pet has no review due, no anniversary card, no vaccination
 * window, no passport, no nudge, no products, no asks. A surface that forgets
 * to check gets nothing to render, which is the right failure.
 *
 * WHAT STAYS: the record. Everything they told us, the photographs, the
 * summary, the diary. Taking it away would be the fifth failure.
 * ═══════════════════════════════════════════════════════════════════════════
 *
 * Pure.
 */
import type { PetProfile } from '../data/types'

/** True once an owner has told us. */
export function isRemembered(pet: Pick<PetProfile, 'diedOn'>): boolean {
  if (!pet.diedOn) return false
  return Number.isFinite(Date.parse(pet.diedOn))
}

/**
 * Everything that must go quiet, named.
 *
 * Exported so a test can enumerate it rather than trusting that each was
 * remembered. Adding a surface means adding it here and proving it is silent.
 */
export const MUST_GO_QUIET = [
  'annual re-projection',
  'gotcha day card',
  'vaccination schedule',
  'socialization passport',
  'plan-accuracy nagging',
  'home nudge',
  'product recommendations',
  'contextual asks',
  'lump diary prompts',
  'protect offer',
  // UAT K2: a score and its verdict are a judgement on how somebody is doing now.
  'clovara score',
  'wellness rider appointments',
] as const

/** What stays reachable, because taking it away would be its own cruelty. */
export const STAYS = [
  'the pet record',
  'photographs',
  'the vet-visit summary',
  'the lump diary as a record',
] as const

export const REMEMBER_HEADLINE = (name: string) => `${name}'s record is still here`

export const REMEMBER_BODY = (name: string) =>
  `We have stopped everything that would have carried on — the reminders, the suggestions, the questions about how ${name} is doing. Nothing has been deleted, and nothing will be. Whenever you want it, it is here.`

/**
 * The one thing this surface asks, and it asks nothing else.
 *
 * No rating, no "tell us more", no offer, and above all no suggestion of
 * another animal. A product that responds to a death by recommending a
 * replacement has said something about how it understood the relationship.
 */
export const REMEMBER_PROMPT = 'Nothing else is needed from you.'
