/**
 * When to ask somebody to keep their pet's plan (ACQUISITION-ONBOARDING-PLAN, AO2).
 *
 * A pet made signed-out lives only in that browser, and nothing used to say so:
 * clear it, or pick up a phone, and the dog was gone. This decides when to say
 * it — and, as importantly, when to stop. Pure.
 *
 * THE RULES
 *   - Never for a demo pet, a signed-in owner, or a pet who has died.
 *   - First ask: straight after the reveal.
 *   - Dismissed once: ask again only after something WORTH KEEPING has been
 *     added since — an answer, a stamp, a recorded vaccination, a medication.
 *     Asking again for nothing new is nagging.
 *   - Never more than twice.
 */
import type { PetProfile } from '../data/types'
import { isRemembered } from './remember'

export const MAX_ASKS = 2

export interface SavePromptMemory {
  /** How many times it was dismissed. */
  dismissals: number
  /** What was worth keeping at the last dismissal, so "something new" is measurable. */
  keptAtDismissal: number
}

/** How much this owner has put into the plan beyond the five reveal questions. */
export function worthKeeping(pet: PetProfile): number {
  const answered = [
    pet.bodyConditionScore !== undefined || (Number.isFinite(pet.weightLb) && pet.weightLb > 0),
    pet.conditionsReviewed === true || pet.conditionIds.length > 0,
    pet.neutered !== undefined,
    !!pet.activity,
    !!pet.dental,
    !!pet.diet,
    !!pet.outdoorAccess,
  ].filter(Boolean).length
  return (
    answered +
    (pet.socialStamps?.length ?? 0) +
    (pet.vaccineRecords?.length ?? 0) +
    (pet.medications?.length ?? 0) +
    (pet.lumps?.length ?? 0) +
    (pet.photo ? 1 : 0)
  )
}

export function shouldAskToSave(
  pet: PetProfile,
  ctx: { signedIn: boolean; memory: SavePromptMemory | null },
): boolean {
  if (ctx.signedIn || pet.demo || isRemembered(pet)) return false
  const m = ctx.memory ?? { dismissals: 0, keptAtDismissal: 0 }
  if (m.dismissals === 0) return true
  if (m.dismissals >= MAX_ASKS) return false
  return worthKeeping(pet) > m.keptAtDismissal
}
