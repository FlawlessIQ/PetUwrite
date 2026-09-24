/**
 * The Socialization Passport (SPEC §6.3): where somebody is in the window, and
 * what is left.
 *
 * Pure; clock injected.
 */
import {
  PASSPORT_VISIBLE_WEEKS,
  SOCIAL_STAMPS,
  WINDOW_WEEKS,
  stampsFor,
  type SocialStamp,
} from '../data/socialization'
import type { PetProfile } from '../data/types'
import { ageInYears } from './project'
import { isRemembered } from './remember'

export const WEEKS_PER_YEAR = 52.1775

export type WindowState =
  /** Inside the sensitive period. */
  | 'open'
  /** Past it, but the passport still earns its keep as habituation. */
  | 'closing'
  /** Past the age where we show it at all. */
  | 'closed'

export interface PassportState {
  visible: boolean
  ageWeeks: number
  window: WindowState
  /** Weeks left in the sensitive period, 0 once it has passed. */
  weeksLeft: number
  stamps: SocialStamp[]
  collected: string[]
  /** Collected ÷ available, 0–1. */
  progress: number
  byGroup: { group: string; total: number; done: number }[]
}

export function passportState(pet: PetProfile, now: Date): PassportState {
  const ageWeeks = ageInYears(pet.birthDate, now) * WEEKS_PER_YEAR
  const win = WINDOW_WEEKS[pet.species]
  const stamps = stampsFor(pet.species)

  // Only ids that still exist. A stamp retired from the content must not keep
  // counting towards somebody's progress, or the passport slowly fills itself.
  const known = new Set(SOCIAL_STAMPS.map((x) => x.id))
  const collected = (pet.socialStamps ?? []).filter((id) => known.has(id))

  const window: WindowState =
    ageWeeks < win.closes ? 'open' : ageWeeks < PASSPORT_VISIBLE_WEEKS ? 'closing' : 'closed'

  const groups = new Map<string, { total: number; done: number }>()
  for (const st of stamps) {
    const g = groups.get(st.group) ?? { total: 0, done: 0 }
    g.total++
    if (collected.includes(st.id)) g.done++
    groups.set(st.group, g)
  }

  return {
    // Silent once a pet has died (SPEC-HORIZON §2.5).
    visible: !isRemembered(pet) && window !== 'closed',
    ageWeeks,
    window,
    weeksLeft: Math.max(0, Math.ceil(win.closes - ageWeeks)),
    stamps,
    collected,
    progress: stamps.length === 0 ? 0 : collected.length / stamps.length,
    byGroup: [...groups].map(([group, g]) => ({ group, ...g })),
  }
}

/**
 * What to say about the window, which is NOT the same sentence for both
 * species.
 *
 * A kitten's sensitive period runs roughly 2–7 weeks and is therefore usually
 * over before they are adopted. Telling their owner to hurry would be selling
 * them a race they never had the chance to enter, and implying they missed
 * something is worse — so the copy says plainly that the early part was the
 * breeder's or the shelter's, and that what remains genuinely still works.
 */
export function windowCopy(pet: PetProfile, state: PassportState): { title: string; body: string } {
  const who = pet.species === 'cat' ? 'kitten' : 'puppy'
  if (state.window === 'open') {
    return {
      title: `${state.weeksLeft} week${state.weeksLeft === 1 ? '' : 's'} of the easy part left`,
      body: `Up to about ${WINDOW_WEEKS[pet.species].closes} weeks, a ${who} accepts new things far more readily than they ever will again. Nothing here is required, and a frightened ${who} has not been socialised — they have been frightened.`,
    }
  }
  if (pet.species === 'cat') {
    return {
      title: 'The early window has already closed',
      body: `A kitten's most receptive weeks are roughly two to seven, which happens before most kittens come home — that part belonged to whoever raised ${pet.name}, not to you. What is below still works, more slowly, and is worth doing.`,
    }
  }
  return {
    title: 'Past the easiest weeks, and still worth doing',
    body: `The most receptive period is behind ${pet.name}, so new things take longer and go at their pace rather than yours. Everything below still counts.`,
  }
}
