import { useState } from 'react'
import type { PetProfile, Projection } from '../data/types'
import { buildCoverage } from '../engine/platform'
import { COVERAGE_DISCLAIMER, PLAN_TIERS } from '../data/coverage'
import { CloverMark } from './CloverMark'

export function Coverage({ pet, projection }: { pet: PetProfile; projection: Projection }) {
  const [tierId, setTierId] = useState('complete')
  const [showMath, setShowMath] = useState(false)
  const c = buildCoverage(pet, projection, tierId)

  return (
    <div className="mx-auto w-full max-w-shell px-5 pb-24 pt-8 sm:pt-10">
      <header className="mb-6">
        <p className="label">Coverage</p>
        <h1 className="mt-1.5 font-display text-[34px] leading-[1.1] text-ink sm:text-[40px]">
          {c.hasPolicy ? `${pet.name} is covered` : `What cover would look like for ${pet.name}`}
        </h1>
        <p className="mt-2 max-w-[62ch] text-[15.5px] leading-relaxed text-ink-2">
          {c.hasPolicy
            ? `Policy ${c.policyNumber}. The wellness rider below reimburses the routine care that ${pet.name}'s life stage actually calls for.`
            : `${pet.name} was added during this session, so there is no policy — here is what one would look like, priced the same way.`}
        </p>
      </header>

      <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)] lg:items-start">
        <div className="space-y-5">
          {/* ── Plan card ─────────────────────────────────────────────── */}
          <section className="card relative overflow-hidden bg-forest p-0 text-white">
            <div aria-hidden="true" className="pointer-events-none absolute -bottom-8 -right-6 rotate-12 opacity-[0.14]">
              <CloverMark size={140} label="" watermark />
            </div>
            <div className="relative px-6 py-6">
              <p className="text-[11px] font-medium uppercase tracking-[0.14em] text-white/70">
                Accident &amp; illness
              </p>
              <h2 className="mt-1 font-display text-[26px] leading-tight">{c.tier.name}</h2>
              <p className="mt-1 text-[13.5px] leading-snug text-white/75">{c.tier.blurb}</p>

              <div className="mt-5 flex flex-wrap gap-x-8 gap-y-4">
                <div>
                  <p className="font-display text-[24px] font-semibold leading-none">
                    ${c.monthlyPremium.toFixed(2)}
                  </p>
                  <p className="mt-1 text-[11.5px] text-white/70">per month</p>
                </div>
                <div>
                  <p className="font-display text-[24px] font-semibold leading-none">{c.tier.reimbursement}%</p>
                  <p className="mt-1 text-[11.5px] text-white/70">reimbursement</p>
                </div>
                <div>
                  <p className="font-display text-[24px] font-semibold leading-none">${c.tier.deductible}</p>
                  <p className="mt-1 text-[11.5px] text-white/70">deductible</p>
                </div>
                <div>
                  <p className="font-display text-[24px] font-semibold leading-none">{c.tier.annualLimit}</p>
                  <p className="mt-1 text-[11.5px] text-white/70">annual limit</p>
                </div>
              </div>

              <div className="mt-5 flex gap-2">
                {PLAN_TIERS.map((t) => (
                  <button
                    key={t.id}
                    type="button"
                    onClick={() => setTierId(t.id)}
                    aria-pressed={t.id === tierId}
                    className={`rounded-full px-4 py-2 text-[13.5px] font-medium transition ${
                      t.id === tierId
                        ? 'bg-white text-deep'
                        : 'border border-white/30 text-white/85 hover:border-white/60'
                    }`}
                  >
                    {t.name.replace('Clovara ', '')}
                  </button>
                ))}
              </div>
            </div>
          </section>

          {/* SPEC §5's second entry point: a quiet line, not a banner. Somebody
              already on this tab is thinking about it without being pushed. */}
          {!c.hasPolicy && (
            <p className="text-[14px] leading-relaxed text-ink-2">
              <a href="#/protect" className="text-forest text-action">
                Take this cover for {pet.name}
              </a>{' '}
              — the price above, and exactly what it does and does not do, before anything is paid.
            </p>
          )}

          {/* ── Premium breakdown ─────────────────────────────────────── */}
          <section className="card overflow-hidden">
            <button
              type="button"
              onClick={() => setShowMath((s) => !s)}
              aria-expanded={showMath}
              className="flex w-full items-center justify-between gap-4 px-5 py-4 text-left sm:px-6"
            >
              <span>
                <span className="block font-display text-[19px] leading-tight text-ink">
                  Why this price
                </span>
                <span className="mt-0.5 block text-[13.5px] text-ink-2">
                  Every factor, shown. No black box.
                </span>
              </span>
              <span
                aria-hidden="true"
                className={`shrink-0 text-[20px] leading-none text-ink-2 transition-transform ${showMath ? 'rotate-45' : ''}`}
              >
                +
              </span>
            </button>

            {showMath && (
              <div className="reveal border-t border-line px-5 py-5 sm:px-6">
                <ul className="space-y-3">
                  {c.breakdown.map((b) => (
                    <li key={b.label} className="flex flex-wrap items-baseline gap-x-3 gap-y-1">
                      <span className="w-[68px] shrink-0 font-display text-[15px] font-semibold text-forest">
                        {b.value}
                      </span>
                      <span className="text-[14.5px] text-ink">{b.label}</span>
                      <span className="w-full pl-[80px] text-[13px] leading-snug text-ink-2">
                        {b.note}
                      </span>
                    </li>
                  ))}
                </ul>
                <div className="mt-4 flex items-baseline justify-between border-t border-line pt-4">
                  <span className="text-[14.5px] text-ink">Accident &amp; illness</span>
                  <span className="font-display text-[18px] font-semibold text-ink">
                    ${c.monthlyPremium.toFixed(2)}
                  </span>
                </div>
                <div className="mt-2 flex items-baseline justify-between">
                  <span className="text-[14.5px] text-ink">Wellness rider</span>
                  <span className="font-display text-[18px] font-semibold text-ink">
                    ${c.riderPrice.toFixed(2)}
                  </span>
                </div>
                <div className="mt-2 flex items-baseline justify-between border-t border-line pt-3">
                  <span className="text-[14.5px] font-medium text-ink">Total each month</span>
                  <span className="font-display text-[21px] font-semibold text-forest">
                    ${c.totalMonthly.toFixed(2)}
                  </span>
                </div>
              </div>
            )}
          </section>

          {/* ── Claim ─────────────────────────────────────────────────── */}
          <section className="card overflow-hidden" aria-labelledby="claim-heading">
            <div className="flex items-center justify-between gap-3 border-b border-line bg-cream/50 px-5 py-4 sm:px-6">
              <h2 id="claim-heading" className="font-display text-[19px] leading-tight text-ink">
                {c.claim ? `Latest claim · ${c.claim.title.toLowerCase()}` : 'How a claim works'}
              </h2>
              {c.claim && (
                <span className="shrink-0 rounded-full bg-sage px-2.5 py-0.5 text-[11px] font-medium uppercase tracking-[0.07em] text-deep">
                  Paid
                </span>
              )}
            </div>

            <ol className="px-5 py-5 sm:px-6">
              {[
                {
                  t: 'Claim submitted',
                  s: c.claim
                    ? `${c.claim.submitted} · ${c.claim.note}`
                    : 'A photo of the invoice. That is the whole submission.',
                },
                {
                  t: c.claim ? `Approved in ${c.claim.approvedHours} hours` : 'Auto-reviewed in hours, not weeks',
                  s: "Reviewed by Clovara's underwriting engine, with a human on the exceptions.",
                },
                {
                  t: c.claim ? `$${c.claim.paid} paid to your account` : 'Paid straight to your account',
                  s: c.claim
                    ? `Same day. $${c.claim.invoice} invoice, ${c.tier.reimbursement}% after deductible.`
                    : `${c.tier.reimbursement}% of the invoice after your $${c.tier.deductible} deductible.`,
                },
              ].map((step, i, arr) => (
                <li key={step.t} className="relative flex gap-4 pb-5 last:pb-0">
                  <div className="flex flex-col items-center">
                    <span aria-hidden="true" className="mt-1 h-3 w-3 shrink-0 rounded-full bg-forest" />
                    {i < arr.length - 1 && <span aria-hidden="true" className="w-[2px] flex-1 bg-line" />}
                  </div>
                  <div className="pb-1">
                    <p className="text-[14.5px] font-medium text-ink">{step.t}</p>
                    <p className="mt-0.5 text-[13px] leading-relaxed text-ink-2">{step.s}</p>
                  </div>
                </li>
              ))}
            </ol>
          </section>
        </div>

        <div className="space-y-5">
          {/* ── Wellness rider — the engine connection ────────────────── */}
          <section className="card overflow-hidden" aria-labelledby="rider-heading">
            <div className="border-b border-line bg-cream/50 px-5 py-4 sm:px-6">
              <h2 id="rider-heading" className="font-display text-[22px] leading-tight text-ink">
                Wellness rider
              </h2>
              <p className="mt-1 text-[14px] leading-snug text-ink-2">
                Routine care, reimbursed. These lines are generated from {pet.name}'s current life
                stage — {projection.currentStage.label.toLowerCase()} — so the policy pays for the
                care the journey is already asking for.
              </p>
            </div>

            <ul className="divide-y divide-line">
              {c.riderItems.map((r) => (
                <li key={r.id} className="px-5 py-4 sm:px-6">
                  <div className="flex items-start justify-between gap-3">
                    <p className="text-[14.5px] font-medium leading-snug text-ink">{r.label}</p>
                    <span className="shrink-0 font-display text-[16px] font-semibold text-forest">
                      ${r.allowance}
                    </span>
                  </div>
                  <p className="mt-1 text-[13px] leading-relaxed text-ink-2">{r.because}</p>
                </li>
              ))}
            </ul>

            <div className="border-t border-line bg-cream/50 px-5 py-4 sm:px-6">
              <div className="flex items-baseline justify-between gap-3">
                <span className="text-[14px] text-ink-2">Reimbursable at this stage, up to</span>
                <span className="font-display text-[20px] font-semibold text-ink">
                  ${c.riderTotal}/yr
                </span>
              </div>
              <p className="mt-1.5 text-[12.5px] leading-relaxed text-ink-2">
                Per-item annual maximums, not an expected payout — most members claim a fraction of
                the total. The rider costs ${c.riderPrice}/mo, or ${c.riderPrice * 12}/yr.
              </p>
            </div>
          </section>

          {/* ── Risk coverage ────────────────────────────────────────── */}
          <section className="card overflow-hidden" aria-labelledby="riskcov-heading">
            <div className="border-b border-line bg-cream/50 px-5 py-4 sm:px-6">
              <h2 id="riskcov-heading" className="font-display text-[22px] leading-tight text-ink">
                {projection.breed.name} risks, and where you stand
              </h2>
              <p className="mt-1 text-[14px] leading-snug text-ink-2">
                The conditions the Life Journey flags for this breed, and whether the plan responds
                to them. Said now, not at claim time.
              </p>
            </div>
            <ul className="divide-y divide-line">
              {c.riskCoverage.map((r) => (
                <li key={r.name} className="flex items-start gap-3 px-5 py-3.5 sm:px-6">
                  <span
                    aria-hidden="true"
                    className={`mt-1 grid h-[18px] w-[18px] shrink-0 place-items-center rounded-full text-[11px] font-semibold ${
                      r.covered ? 'bg-sage text-deep' : 'bg-accent/15 text-[#8A5510]'
                    }`}
                  >
                    {r.covered ? '✓' : '!'}
                  </span>
                  <div>
                    <p className="text-[14.5px] font-medium text-ink">{r.name}</p>
                    <p className="mt-0.5 text-[13px] leading-relaxed text-ink-2">{r.note}</p>
                  </div>
                </li>
              ))}
            </ul>
          </section>

          <section className="card space-y-3 px-5 py-5 sm:px-6">
            <h2 className="label">How this fits together</h2>
            <p className="text-[14px] leading-relaxed text-ink/80">
              Membership and insurance are priced and sold separately. Rewards points redeem toward
              products and care services, never toward premium — behaviour-based premium discounts
              are a rate-filing question in most states, and this demo does not pretend otherwise.
            </p>
            <p className="text-[14px] leading-relaxed text-ink/80">
              Companion conversations are firewalled from underwriting and claims. What you tell the
              assistant does not price your policy.
            </p>
          </section>
        </div>
      </div>

      <p className="mt-6 rounded-soft border border-accent/25 bg-accent/[0.07] px-4 py-3 text-[13px] leading-relaxed text-[#8A5510]">
        <strong className="font-semibold">Illustrative pricing.</strong> {COVERAGE_DISCLAIMER} It
        carries no expense or jurisdictional loading and has not been through a rate filing.
      </p>
    </div>
  )
}
