import type { PetProfile } from '../data/types'
import { explainRenewal, RENEWAL_EXPLAINED_ENABLED } from '../engine/renewal'

/**
 * Renewal, Explained (SPEC §6.8).
 *
 * Ships behind `RENEWAL_EXPLAINED_ENABLED`, which is off: nothing can be
 * renewed until the carrier program is live, and a renewal screen driven by
 * illustrative numbers is a screen about nothing.
 *
 * The second half of the page is the point. Anyone can list the factors that
 * pushed a price up; naming the ones that will never be in it — the companion,
 * the tracker, the streaks, whether you opened the app — is the part that makes
 * the first half believable, and it is what the Data Covenant promised.
 */
export function RenewalExplained({
  pet,
  prior,
  current,
  currency = '$',
}: {
  pet: PetProfile
  prior: { monthly: number; ageYears: number }
  current: { monthly: number; ageYears: number; claimsLastYear: number; filedRateChange?: number }
  currency?: string
}) {
  if (!RENEWAL_EXPLAINED_ENABLED) return null
  const r = explainRenewal(pet, prior, current)
  const money = (n: number) => `${n < 0 ? '−' : ''}${currency}${Math.abs(n).toFixed(2)}`

  return (
    <section className="card overflow-hidden" aria-labelledby="renewal-heading">
      <div className="border-b border-line bg-cream/50 px-5 py-4">
        <p className="label">Renewal</p>
        <h2 id="renewal-heading" className="mt-1 font-display text-[20px] text-ink">
          {r.unchanged
            ? `${pet.name}'s premium has not changed`
            : `Why ${pet.name}'s premium is ${money(r.newMonthly)}`}
        </h2>
        <p className="mt-1 text-[13.5px] text-ink-2">
          Was {money(r.priorMonthly)} a month. Every part of the change is below.
        </p>
      </div>

      <ul className="divide-y divide-line">
        {r.lines.map((l) => (
          <li key={l.id} className="px-5 py-4">
            <div className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1">
              <p className="text-[15px] text-ink">{l.label}</p>
              <p className="text-[15px] font-medium text-deep">
                {l.delta === 0 ? 'no change' : money(l.delta)}
              </p>
            </div>
            <p className="mt-1 text-[13.5px] leading-relaxed text-ink-2">{l.because}</p>
          </li>
        ))}
      </ul>

      <div className="border-t border-line bg-sage/40 px-5 py-4">
        <p className="text-[14px] font-medium text-deep">What is not in this price</p>
        <ul className="mt-2 space-y-1.5">
          {r.notFactors.map((n) => (
            <li key={n} className="text-[13.5px] leading-relaxed text-deep">
              {n}
            </li>
          ))}
        </ul>
        <p className="mt-3 text-[12.5px] leading-relaxed text-ink-2">
          This is the Data Covenant in practice: what you tell us works for your pet, and never
          against your price — not up, and not down as a reward for behaving.
        </p>
      </div>
    </section>
  )
}
