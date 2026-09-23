/**
 * Renewal, Explained (SPEC §6.8): why the premium is what it is, at the moment
 * somebody is deciding whether to keep paying it.
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * A DELIBERATE DEPARTURE FROM THE JOURNEY COPY, AND THE REASON FOR IT.
 *
 * The journey map describes this moment as "why her premium is what it is —
 * and what her care this year kept it from being". The second half cannot be
 * built as written. The Data Covenant (invariant 5, shipped in P1.5) promises
 * that this data does not change a premium "not up, and not down as a reward
 * for behaving — which is the same promise". A renewal screen crediting an
 * owner for their care would break the covenant in the direction people find
 * pleasant, which is exactly the direction a product like this drifts.
 *
 * Claims experience is a different thing and is a legitimate, filed rating
 * factor everywhere insurance is sold: whether a policy was claimed on is not
 * a behaviour score. So the breakdown may say "no claims this year" and may
 * not say "your dental streak saved you £4".
 *
 * The screen therefore does something better than the original: it lists what
 * DID move the price, and then names what did not and never will. At renewal,
 * the sentence "none of this came from your tracker or your companion
 * conversations" is worth more than a discount.
 * ═══════════════════════════════════════════════════════════════════════════
 *
 * Pure; clock injected. Off behind a flag until real policies exist.
 */
import type { PetProfile } from '../data/types'

/**
 * SPEC §6.8: "template exists behind a flag; activates with real policies."
 * Nothing real can be renewed until the carrier program is live, and a renewal
 * screen driven by illustrative numbers would be a screen about nothing.
 */
export const RENEWAL_EXPLAINED_ENABLED = false

export interface RenewalLine {
  id: string
  label: string
  /** "+£2.10", "no change", "−£0.80". Formatted by the caller's currency. */
  delta: number
  because: string
}

export interface RenewalExplanation {
  priorMonthly: number
  newMonthly: number
  lines: RenewalLine[]
  /** What is NOT in the price, named explicitly. */
  notFactors: string[]
  unchanged: boolean
}

/**
 * The factors we are willing to show, and no others.
 *
 * Every one of these is something a filing would contain. Nothing derived from
 * the companion, the passport, the streaks or a tracker appears here, and
 * `notFactors` says so on the page rather than leaving it to be inferred.
 */
export function explainRenewal(
  pet: PetProfile,
  prior: { monthly: number; ageYears: number },
  current: { monthly: number; ageYears: number; claimsLastYear: number; filedRateChange?: number },
): RenewalExplanation {
  const lines: RenewalLine[] = []
  const round = (n: number) => Math.round(n * 100) / 100

  const ageYears = Math.floor(current.ageYears) - Math.floor(prior.ageYears)
  if (ageYears > 0) {
    lines.push({
      id: 'age',
      label: `${pet.name} is a year older`,
      delta: round((current.monthly - prior.monthly) * 0.7),
      because:
        'Claims get more likely with age in every species and every breed. It is the one factor that moves every year and the one nobody can do anything about.',
    })
  }

  lines.push({
    id: 'claims',
    label:
      current.claimsLastYear === 0
        ? 'No claims in the last year'
        : `${current.claimsLastYear} claim${current.claimsLastYear === 1 ? '' : 's'} in the last year`,
    delta: current.claimsLastYear === 0 ? 0 : round((current.monthly - prior.monthly) * 0.3),
    because:
      current.claimsLastYear === 0
        ? 'Whether a policy was claimed on is a rating factor, and it is a filed one. It is not a score for how you looked after them.'
        : 'Claims experience is a filed rating factor. It reflects what the policy paid out, not how you cared for them.',
  })

  if (current.filedRateChange) {
    lines.push({
      id: 'filed',
      label: 'A change to our filed rates',
      delta: round(current.filedRateChange),
      because:
        'Rates are filed with regulators and change for everyone in a class at once. This part has nothing to do with your pet.',
    })
  }

  return {
    priorMonthly: prior.monthly,
    newMonthly: current.monthly,
    lines,
    notFactors: [
      'Anything your companion conversations contained.',
      'Anything a tracker measured — steps, sleep, activity.',
      'Your Clovara score, your streaks, or your passport.',
      'Whether you read our emails, or opened the app at all.',
    ],
    unchanged: Math.abs(current.monthly - prior.monthly) < 0.005,
  }
}
