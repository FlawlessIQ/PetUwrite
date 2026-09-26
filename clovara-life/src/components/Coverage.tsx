import { useState } from 'react'
import type { PetProfile, Projection } from '../data/types'
import { buildCoverage } from '../engine/platform'
import { COVERAGE_DISCLAIMER, PLAN_TIERS } from '../data/coverage'
import { CloverMark } from './CloverMark'
import { Icon } from './Icon'
import { Quiet } from './Quiet'

export function Coverage({ pet, projection }: { pet: PetProfile; projection: Projection }) {
  const [tierId, setTierId] = useState('complete')
  const [showMath, setShowMath] = useState(false)
  const c = buildCoverage(pet, projection, tierId)

  // Null once a pet has died. No policy can be bound today (canBind is false),
  // so there is no live policy to show here; what happens to one when there
  // is belongs to the carrier programme (BACKLOG B4), not to this screen.
  if (!c) {
    return (
      <Quiet label="Coverage" pet={pet}>
        There is no cover to offer for {pet.name}, and we are not going to price one.
      </Quiet>
    )
  }

  return (
    <div className="mx-auto w-full max-w-shell px-5 pb-24 pt-8 sm:pt-10">
      <header className="mb-6">
        <p className="label">Coverage</p>
        <h1 className="mt-1.5 font-display text-display-lg leading-[1.1] text-ink sm:text-display-xl">
          {c.hasPolicy ? `${pet.name} is covered` : `What cover would look like for ${pet.name}`}
        </h1>
        <p className="mt-2 max-w-[62ch] text-lead leading-relaxed text-ink-2">
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
              <p className="text-caption font-semibold uppercase tracking-[0.18em] text-white/70">
                Accident &amp; illness
              </p>
              <h2 className="mt-1 font-display text-display-sm leading-tight">{c.tier.name}</h2>
              <p className="mt-1 text-body leading-snug text-white/75">{c.tier.blurb}</p>

              <div className="mt-5 flex flex-wrap gap-x-8 gap-y-4">
                <div>
                  <p className="font-display text-stat font-semibold leading-none">
                    ${c.monthlyPremium.toFixed(2)}
                  </p>
                  <p className="mt-1 text-caption text-white/70">per month</p>
                </div>
                <div>
                  <p className="font-display text-stat font-semibold leading-none">{c.tier.reimbursement}%</p>
                  <p className="mt-1 text-caption text-white/70">reimbursement</p>
                </div>
                <div>
                  <p className="font-display text-stat font-semibold leading-none">${c.tier.deductible}</p>
                  <p className="mt-1 text-caption text-white/70">deductible</p>
                </div>
                <div>
                  <p className="font-display text-stat font-semibold leading-none">{c.tier.annualLimit}</p>
                  <p className="mt-1 text-caption text-white/70">annual limit</p>
                </div>
              </div>

              <div className="mt-5 flex gap-2">
                {PLAN_TIERS.map((t) => (
                  <button
                    key={t.id}
                    type="button"
                    onClick={() => setTierId(t.id)}
                    aria-pressed={t.id === tierId}
                    className={`rounded-full px-4 py-2 text-body font-medium transition ${
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
            <p className="text-body-lg leading-relaxed text-ink-2">
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
                <span className="block font-display text-heading-sm leading-tight text-ink">
                  Why this price
                </span>
                <span className="mt-0.5 block text-body text-ink-2">
                  Every factor, shown. No black box.
                </span>
              </span>
              <span
                aria-hidden="true"
                className={`shrink-0 text-heading leading-none text-ink-2 transition-transform ${showMath ? 'rotate-45' : ''}`}
              >
                +
              </span>
            </button>

            {showMath && (
              <div className="reveal border-t border-line px-5 py-5 sm:px-6">
                <ul className="space-y-3">
                  {c.breakdown.map((b) => (
                    <li key={b.label} className="flex flex-wrap items-baseline gap-x-3 gap-y-1">
                      <span className="w-[68px] shrink-0 font-display text-lead font-semibold text-forest">
                        {b.value}
                      </span>
                      <span className="text-body-lg text-ink">{b.label}</span>
                      <span className="w-full pl-[80px] text-body-sm leading-snug text-ink-2">
                        {b.note}
                      </span>
                    </li>
                  ))}
                </ul>
                <div className="mt-4 flex items-baseline justify-between border-t border-line pt-4">
                  <span className="text-body-lg text-ink">Accident &amp; illness</span>
                  <span className="font-display text-heading-sm font-semibold text-ink">
                    ${c.monthlyPremium.toFixed(2)}
                  </span>
                </div>
                <div className="mt-2 flex items-baseline justify-between">
                  <span className="text-body-lg text-ink">Wellness rider</span>
                  <span className="font-display text-heading-sm font-semibold text-ink">
                    ${c.riderPrice.toFixed(2)}
                  </span>
                </div>
                <div className="mt-2 flex items-baseline justify-between border-t border-line pt-3">
                  <span className="text-body-lg font-medium text-ink">Total each month</span>
                  <span className="font-display text-heading font-semibold text-forest">
                    ${c.totalMonthly.toFixed(2)}
                  </span>
                </div>
              </div>
            )}
          </section>

          {/* ── Claim ─────────────────────────────────────────────────── */}
          <section className="card overflow-hidden" aria-labelledby="claim-heading">
            <div className="flex items-center justify-between gap-3 border-b border-line bg-cream/50 px-5 py-4 sm:px-6">
              <h2 id="claim-heading" className="font-display text-heading-sm leading-tight text-ink">
                {c.claim ? `Latest claim · ${c.claim.title.toLowerCase()}` : 'How a claim works'}
              </h2>
              {c.claim && (
                <span className="chip-good shrink-0">
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
                    <p className="text-body-lg font-medium text-ink">{step.t}</p>
                    <p className="mt-0.5 text-body-sm leading-relaxed text-ink-2">{step.s}</p>
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
              <h2 id="rider-heading" className="font-display text-heading-lg leading-tight text-ink">
                Wellness rider
              </h2>
              <p className="mt-1 text-body-lg leading-snug text-ink-2">
                Routine care, reimbursed. These lines are generated from {pet.name}'s current life
                stage — {projection.currentStage.label.toLowerCase()} — so the policy pays for the
                care the journey is already asking for.
              </p>
            </div>

            <ul className="divide-y divide-line">
              {c.riderItems.map((r) => (
                <li key={r.id} className="px-5 py-4 sm:px-6">
                  <div className="flex items-start justify-between gap-3">
                    <p className="text-body-lg font-medium leading-snug text-ink">{r.label}</p>
                    <span className="shrink-0 font-display text-title font-semibold text-forest">
                      ${r.allowance}
                    </span>
                  </div>
                  <p className="mt-1 text-body-sm leading-relaxed text-ink-2">{r.because}</p>
                </li>
              ))}
            </ul>

            <div className="border-t border-line bg-cream/50 px-5 py-4 sm:px-6">
              <div className="flex items-baseline justify-between gap-3">
                <span className="text-body-lg text-ink-2">Reimbursable at this stage, up to</span>
                <span className="font-display text-heading font-semibold text-ink">
                  ${c.riderTotal}/yr
                </span>
              </div>
              <p className="mt-1.5 text-body-sm leading-relaxed text-ink-2">
                Per-item annual maximums, not an expected payout — most members claim a fraction of
                the total. The rider costs ${c.riderPrice}/mo, or ${c.riderPrice * 12}/yr.
              </p>
            </div>
          </section>

          {/* ── Risk coverage ────────────────────────────────────────── */}
          <section className="card overflow-hidden" aria-labelledby="riskcov-heading">
            <div className="border-b border-line bg-cream/50 px-5 py-4 sm:px-6">
              <h2 id="riskcov-heading" className="font-display text-heading-lg leading-tight text-ink">
                {projection.breed.name} risks, and where you stand
              </h2>
              <p className="mt-1 text-body-lg leading-snug text-ink-2">
                The conditions the Life Journey flags for this breed, and whether the plan responds
                to them. Said now, not at claim time.
              </p>
            </div>
            <ul className="divide-y divide-line">
              {c.riskCoverage.map((r) => (
                <li key={r.name} className="flex items-start gap-3 px-5 py-3.5 sm:px-6">
                  <span
                    aria-hidden="true"
                    className={`mt-1 grid h-[18px] w-[18px] shrink-0 place-items-center rounded-full text-caption font-semibold ${
                      r.covered ? 'bg-sage text-deep' : 'bg-accent/15 text-amber'
                    }`}
                  >
                    {r.covered ? <Icon name="check" size={12} active /> : '!'}
                  </span>
                  <div>
                    <p className="text-body-lg font-medium text-ink">{r.name}</p>
                    <p className="mt-0.5 text-body-sm leading-relaxed text-ink-2">{r.note}</p>
                  </div>
                </li>
              ))}
            </ul>
          </section>

          <section className="card space-y-3 px-5 py-5 sm:px-6">
            <h2 className="label">How this fits together</h2>
            <p className="text-body-lg leading-relaxed text-ink/80">
              Membership and insurance are priced and sold separately. Rewards points redeem toward
              products and care services, never toward premium — behaviour-based premium discounts
              are a rate-filing question in most states, and this demo does not pretend otherwise.
            </p>
            <p className="text-body-lg leading-relaxed text-ink/80">
              Companion conversations are firewalled from underwriting and claims. What you tell the
              assistant does not price your policy.
            </p>
          </section>
        </div>
      </div>

      <p className="mt-6 rounded-soft border border-accent/25 bg-accent/[0.07] px-4 py-3 text-body-sm leading-relaxed text-amber">
        <strong className="font-semibold">Illustrative pricing.</strong> {COVERAGE_DISCLAIMER} It
        carries no expense or jurisdictional loading and has not been through a rate filing.
      </p>
    </div>
  )
}
