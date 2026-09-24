/**
 * Second opinion (SPEC-HORIZON §1.3): which questions, for this situation.
 *
 * Pure, and rule-based rather than model-backed. A model is not needed to know
 * that somebody facing surgery should ask about the anaesthetic, and a model
 * here would be one more place a clinical opinion could leak out.
 */
import { QUESTIONS, type Question } from '../data/secondOpinion'
import { KNOWN_CONDITIONS } from '../data/conditions'
import type { PetProfile, Projection } from '../data/types'

const norm = (s: string) =>
  s.toLowerCase().replace(/[’']/g, "'").replace(/[^a-z0-9' ]+/g, ' ').replace(/\s+/g, ' ').trim()

export interface OpinionResult {
  questions: Question[]
  /** Things from this pet's own record worth raising. Never a diagnosis. */
  fromTheRecord: string[]
}

/**
 * The universal questions always come; the triggered ones join them.
 *
 * Ordering is stable and deliberate: "what if we do nothing" first, because it
 * is the comparison every recommendation has and the one least often stated.
 */
export function questionsFor(
  said: string,
  pet: PetProfile,
  projection: Projection,
): OpinionResult {
  const text = norm(said)
  const questions = QUESTIONS.filter(
    (q) => !q.when || q.when.some((w) => text.includes(norm(w))),
  )

  // Things on the record a vet would want raised. Stated as facts the owner
  // already gave us, never as relevance we have judged.
  const fromTheRecord: string[] = []
  for (const id of pet.conditionIds ?? []) {
    const name = KNOWN_CONDITIONS.find((k) => k.id === id)?.name ?? id
    fromTheRecord.push(`${name} is on ${pet.name}'s record — worth making sure they know.`)
  }
  if (pet.careNotes?.meds) {
    fromTheRecord.push(`${pet.name} is taking: ${pet.careNotes.meds}`)
  }
  if (projection.ageYears >= 8) {
    fromTheRecord.push(
      `${pet.name} is ${Math.floor(projection.ageYears)}, which is worth saying out loud when anything involves an anaesthetic.`,
    )
  }

  return { questions, fromTheRecord }
}
