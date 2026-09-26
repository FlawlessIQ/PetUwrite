/**
 * The senior suite (SPEC-HORIZON §1.5): what changes, and when it starts.
 *
 * Pure. Almost entirely assembly over what the engine already knows — the AAHA
 * life stages, the per-stage care actions, and the risk cards whose windows
 * have opened. It computes nothing new, which is the point.
 *
 * IT NEVER ESTIMATES REMAINING TIME. The healthy-years projection is a planning
 * range built from breed medians; in front of the owner of a thirteen-year-old
 * it would read as a countdown. Same rule as the vet summary and the share
 * cards, and it matters most here.
 */
import { ADAPTATIONS, WORTH_MENTIONING, type Adaptation } from '../data/senior'
import type { PetProfile, Projection, RiskCard, Species } from '../data/types'
import { isRemembered } from './remember'

/**
 * The stages this surface applies to.
 *
 * Only the senior stage. This used to also list 'mature' and 'geriatric', which
 * are not stage ids — the real ones are 'mature-adult' and there is no
 * geriatric stage — so they never matched and only made the list misleading
 * (UAT K6). A test now requires every id here to be a real stage.
 */
export const SENIOR_STAGES = ['senior'] as const

export interface SeniorState {
  visible: boolean
  stageLabel: string
  /** The stage's own summary, from the engine. */
  stageSummary: string
  /** Care actions the engine already carries for this stage. */
  careActions: string[]
  /** Risk windows that have actually opened, not everything on the breed. */
  openNow: RiskCard[]
  adaptations: Adaptation[]
  worthMentioning: string[]
}

function adaptationsFor(species: Species): Adaptation[] {
  return ADAPTATIONS.filter((a) => a.species.includes(species))
}

export function seniorState(pet: PetProfile, projection: Projection): SeniorState {
  const stage = projection.currentStage
  const isSenior = (SENIOR_STAGES as readonly string[]).includes(stage.id)

  return {
    // Silent for a young animal, and silent once they have died.
    visible: isSenior && !isRemembered(pet),
    stageLabel: stage.label,
    stageSummary: stage.summary,
    careActions: stage.recommendations ?? [],
    // Only windows that are open. Listing everything a breed might ever face
    // turns a page about making the house easier into a list of things to
    // dread.
    openNow: projection.riskCards.filter(
      (c) => c.mode === 'active' || c.mode === 'manage',
    ),
    adaptations: adaptationsFor(pet.species),
    worthMentioning: WORTH_MENTIONING[pet.species],
  }
}
