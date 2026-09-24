/**
 * Gotcha Day (SPEC §6.7): the homecoming anniversary, and the card for it.
 *
 * Pure; clock injected. Uses `knownSince` — the date stored at creation — which
 * is the homecoming rather than the birthday. For a rescue those are years
 * apart and the homecoming is the one the family actually marks.
 */
import type { PetProfile } from '../data/types'
import { isRemembered } from './remember'

const DAY = 86_400_000

export interface GotchaState {
  /** Offer the card. */
  active: boolean
  /** Whole years home, on this anniversary. */
  years: number
  /** Days since the anniversary — 0 on the day itself. */
  daysSince: number
}

/**
 * How long the card stays on offer after the day.
 *
 * A week, because people miss it. A prompt that appears only on the exact day
 * is a prompt most families never see, and one that lingers for a month stops
 * meaning anything.
 */
export const GOTCHA_WINDOW_DAYS = 7

export function gotchaState(pet: PetProfile, now: Date): GotchaState {
  const blank: GotchaState = { active: false, years: 0, daysSince: 0 }
  // Silent once a pet has died (SPEC-HORIZON §2.5). Enforced here rather
  // than in each surface, so a component that forgets to check renders nothing.
  if (isRemembered(pet)) return blank
  if (!pet.knownSince) return blank
  const home = new Date(pet.knownSince)
  if (Number.isNaN(home.getTime())) return blank

  // This calendar year's anniversary, at midnight UTC.
  const anniversary = new Date(
    Date.UTC(now.getUTCFullYear(), home.getUTCMonth(), home.getUTCDate()),
  )
  // Not reached yet this year — use last year's.
  if (anniversary.getTime() > now.getTime()) {
    anniversary.setUTCFullYear(anniversary.getUTCFullYear() - 1)
  }

  const years = anniversary.getUTCFullYear() - home.getUTCFullYear()
  // Nothing to celebrate on the day they arrived, and nothing before a year.
  if (years < 1) return blank

  const daysSince = Math.floor((now.getTime() - anniversary.getTime()) / DAY)
  return {
    active: daysSince >= 0 && daysSince < GOTCHA_WINDOW_DAYS,
    years,
    daysSince,
  }
}
