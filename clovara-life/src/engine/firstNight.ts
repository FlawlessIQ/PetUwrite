/**
 * First-Night Mode (SPEC §6.2): which of the first seventy-two hours somebody
 * is in, and what to show them.
 *
 * Pure. The clock is injected, as everywhere else in the engine.
 */
import { FIRST_NIGHT_BLOCKS, type FirstNightBlock } from '../data/firstNight'
import type { PetProfile } from '../data/types'
import { ageInYears } from './project'

/** SPEC §6.2: puppies and kittens under twelve weeks. */
export const FIRST_NIGHT_MAX_AGE_WEEKS = 12
export const FIRST_NIGHT_HOURS = 72

export interface FirstNightState {
  active: boolean
  hoursHome: number
  current: FirstNightBlock | null
  /** Everything after the current block, so somebody can read ahead at 2am. */
  upcoming: FirstNightBlock[]
  /** Why it is not showing, for the surface to explain rather than vanish. */
  reason?: 'too-old' | 'over-72-hours' | 'unknown-arrival'
}

export function firstNightState(pet: PetProfile, now: Date): FirstNightState {
  const blank: FirstNightState = { active: false, hoursHome: 0, current: null, upcoming: [] }

  if (!pet.knownSince) return { ...blank, reason: 'unknown-arrival' }
  const arrived = Date.parse(pet.knownSince)
  if (!Number.isFinite(arrived)) return { ...blank, reason: 'unknown-arrival' }

  const hoursHome = (now.getTime() - arrived) / 3_600_000
  // A clock that moved backwards, or a knownSince in the future. Treat as hour
  // zero rather than showing nothing — somebody is standing in their hallway.
  const hours = Math.max(0, hoursHome)

  const ageWeeks = ageInYears(pet.birthDate, now) * 52.1775
  if (!Number.isFinite(ageWeeks)) return { ...blank, hoursHome: hours, reason: 'unknown-arrival' }
  if (ageWeeks >= FIRST_NIGHT_MAX_AGE_WEEKS) {
    return { ...blank, hoursHome: hours, reason: 'too-old' }
  }
  if (hours >= FIRST_NIGHT_HOURS) {
    return { ...blank, hoursHome: hours, reason: 'over-72-hours' }
  }

  const forSpecies = FIRST_NIGHT_BLOCKS.filter((b) => !b.species || b.species === pet.species)
  const current = forSpecies.find((b) => hours >= b.from && hours < b.to) ?? null
  const upcoming = forSpecies.filter((b) => b.from > hours)

  return { active: current !== null, hoursHome: hours, current, upcoming }
}

/**
 * "{name} has been home about N hours."
 *
 * One rounded number decides both the figure and the plural — they used to be
 * rounded separately, so the first half hour read "about 1 hours" (UAT K4).
 * Floored at one: "about 0 hours" says nobody is home yet.
 */
export function hoursHomeLine(name: string, hoursHome: number): string {
  const n = Math.max(1, Math.round(hoursHome))
  return `${name} has been home about ${n} hour${n === 1 ? '' : 's'}.`
}
