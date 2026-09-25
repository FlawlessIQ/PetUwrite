import { useMemo, useRef, useState } from 'react'
import type { PetProfile, Projection } from '../data/types'
import { PLAN_TIERS } from '../data/coverage'
import {
  ATTESTATION,
  DISCLOSURES,
  FRAUD_NOTICE,
  ILLUSTRATIVE_LABEL,
} from '../data/attach'
import {
  datedWaiting,
  earliestEffective,
  noPreExistingLine,
  preExistingPicture,
  ratingAdapter,
  type QuoteOptions,
} from '../engine/attach'
import { longDate } from '../share/cardLayout'
import { track } from '../analytics/track'

/**
 * The attach flow (SPEC §5). Two screens and no form.
 *
 * Screen 1 is a price somebody did not have to ask for. Screen 2 is the screen
 * of truth, and it is deliberately the less comfortable of the two: waiting
 * periods as dates, the pre-existing picture in words, and the disclosures
 * behind a scroll that has to reach the bottom before the button works. The
 * commonest reason a pet claim is declined is a pre-existing condition, and the
 * commonest reason the owner is blindsided is that nobody said it in words
 * before they paid.
 */
export function Attach({
  pet,
  projection,
  onClose,
}: {
  pet: PetProfile
  projection: Projection
  onClose: () => void
}) {
  const adapter = ratingAdapter()
  const [step, setStep] = useState<1 | 2>(1)
  const [opts, setOpts] = useState<QuoteOptions>(() => adapter.smartDefault(pet, projection))
  const [adjusting, setAdjusting] = useState(false)
  const [readToEnd, setReadToEnd] = useState(false)
  const [attested, setAttested] = useState(false)
  const [binding, setBinding] = useState(false)
  const [bindNote, setBindNote] = useState<string | null>(null)
  const scrollRef = useRef<HTMLDivElement | null>(null)

  const quote = useMemo(
    () => adapter.quote(pet, projection, opts),
    [adapter, pet, projection, opts],
  )
  const effective = earliestEffective(new Date())
  const waiting = datedWaiting(effective)
  const preExisting = preExistingPicture(pet)
  const money = (n: number) => `$${n.toFixed(2)}`

  const goToTruth = () => {
    setStep(2)
    track('attach_truth_viewed', {
      tier: opts.tierId,
      rider: opts.rider,
      pet_is_demo: !!pet.demo,
    })
    window.scrollTo({ top: 0 })
  }

  const bind = async () => {
    setBinding(true)
    const r = await adapter.bind({
      petId: pet.id,
      tierId: opts.tierId,
      rider: opts.rider,
      effectiveDate: effective.toISOString().slice(0, 10),
    })
    setBinding(false)
    track(r.ok ? 'attach_bound' : 'attach_offer_viewed', {
      tier: opts.tierId,
      adapter: adapter.id,
      pet_is_demo: !!pet.demo,
    })
    setBindNote(r.ok ? `Covered from ${longDate(effective)}.` : (r.unavailableReason ?? null))
  }

  const onScroll = () => {
    const el = scrollRef.current
    if (!el) return
    if (el.scrollTop + el.clientHeight >= el.scrollHeight - 24) setReadToEnd(true)
  }

  return (
    <div className="mx-auto w-full max-w-[720px] px-5 pb-24 pt-6">
      <div className="mb-4 flex items-center justify-between gap-3">
        <p className="label">Protect {pet.name} · step {step} of 2</p>
        <button type="button" onClick={onClose} className="pill-ghost px-4 py-2 text-[13.5px]">
          Not now
        </button>
      </div>

      {step === 1 ? (
        <>
          <section className="card overflow-hidden">
            <div className="bg-deep px-5 py-6 text-white sm:px-6">
              <p className="text-[13.5px] text-white/75">{quote.tier.name}</p>
              <p className="mt-1 font-display text-[40px] leading-none">
                {money(quote.totalMonthly)}
                <span className="ml-2 text-[16px] font-normal text-white/70">a month</span>
              </p>
              <p className="mt-2 text-[13.5px] leading-relaxed text-white/80">
                {money(quote.monthlyPremium)} insurance
                {quote.riderPrice > 0 && <> · {money(quote.riderPrice)} wellness rider</>}. Two
                separate lines, always.
              </p>
            </div>

            {/* Invariant 2, driven by the adapter rather than hardcoded. */}
            {quote.illustrative && (
              <p className="border-b border-accent/30 bg-accent/12 px-5 py-3 text-[13px] leading-relaxed text-[#8A5510] sm:px-6">
                {ILLUSTRATIVE_LABEL}
              </p>
            )}

            <div className="px-5 py-5 sm:px-6">
              <p className="text-[15px] leading-relaxed text-ink">
                Worked out from {pet.name}&rsquo;s plan — their breed, their age and what you have
                told us. You did not have to fill in a form, and we did not ask you anything we
                already knew.
              </p>

              <button
                type="button"
                onClick={() => setAdjusting((a) => !a)}
                aria-expanded={adjusting}
                className="mt-4 text-[14px] text-forest text-action"
              >
                {adjusting ? 'Hide options' : 'Adjust'}
              </button>

              {adjusting && (
                <div className="mt-4 space-y-4">
                  <div className="flex flex-wrap gap-2">
                    {PLAN_TIERS.map((t) => (
                      <button
                        key={t.id}
                        type="button"
                        aria-pressed={opts.tierId === t.id}
                        onClick={() => setOpts((o) => ({ ...o, tierId: t.id }))}
                        className={`rounded-soft border px-4 py-3 text-left transition ${
                          opts.tierId === t.id ? 'border-forest bg-sage/50' : 'border-line bg-white'
                        }`}
                      >
                        <span className="block text-[14.5px] font-medium text-ink">{t.name}</span>
                        <span className="mt-0.5 block text-[12.5px] text-ink-2">
                          {t.reimbursement}% back · ${t.deductible} deductible · {t.annualLimit}
                        </span>
                      </button>
                    ))}
                  </div>
                  <label className="flex items-start gap-3 text-[14.5px] text-ink">
                    <input
                      type="checkbox"
                      checked={opts.rider}
                      onChange={(e) => setOpts((o) => ({ ...o, rider: e.target.checked }))}
                      className="mt-1"
                    />
                    <span>
                      Add the wellness rider
                      <span className="block text-[12.5px] text-ink-2">
                        Routine care — not insurance, and billed as its own line.
                      </span>
                    </span>
                  </label>
                </div>
              )}

              <details className="mt-5">
                <summary className="cursor-pointer text-[14px] text-forest">
                  Why this price
                </summary>
                <ul className="mt-3 divide-y divide-line border-t border-line">
                  {quote.breakdown.map((b) => (
                    <li key={b.label} className="py-2.5">
                      <div className="flex items-baseline justify-between gap-4">
                        <span className="text-[14px] text-ink">{b.label}</span>
                        <span className="text-[14px] font-medium text-deep">{b.value}</span>
                      </div>
                      <p className="mt-0.5 text-[12.5px] leading-relaxed text-ink-2">{b.note}</p>
                    </li>
                  ))}
                </ul>
              </details>
            </div>
          </section>

          <button type="button" className="pill-primary mt-5 w-full" onClick={goToTruth}>
            See exactly what this covers
          </button>
        </>
      ) : (
        <>
          <section className="card overflow-hidden">
            <div className="border-b border-line bg-cream/50 px-5 py-4">
              <h2 className="font-display text-[21px] text-ink">What you would actually be buying</h2>
              <p className="mt-1 text-[13.5px] leading-relaxed text-ink-2">
                The uncomfortable page, on purpose. Everything here is a reason a claim gets turned
                down, and it is better to read it now than to find out later.
              </p>
            </div>

            <div className="px-5 py-5">
              <p className="label">Cover would start</p>
              <p className="mt-1 text-[15px] text-ink">{longDate(effective)}</p>

              <p className="label mt-5">But not all at once</p>
              <ul className="mt-2 divide-y divide-line border-t border-line">
                {waiting.map((w) => (
                  <li key={w.id} className="py-3">
                    <div className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1">
                      <span className="text-[14.5px] text-ink">{w.label}</span>
                      <span className="text-[14px] font-medium text-deep">
                        from {longDate(w.coveredFrom)}
                      </span>
                    </div>
                    <p className="mt-0.5 text-[12.5px] leading-relaxed text-ink-2">{w.because}</p>
                  </li>
                ))}
              </ul>

              <p className="label mt-5">What is already excluded</p>
              {preExisting.length > 0 ? (
                <ul className="mt-2 space-y-2.5">
                  {preExisting.map((p) => (
                    <li
                      key={p.conditionId}
                      className="rounded-soft border border-accent/30 bg-accent/10 px-4 py-3 text-[14px] leading-relaxed text-[#8A5510]"
                    >
                      {p.meaning}
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="mt-2 text-[14px] leading-relaxed text-ink">{noPreExistingLine(pet)}</p>
              )}
            </div>
          </section>

          <section className="card mt-5 overflow-hidden">
            <div className="border-b border-line bg-cream/50 px-5 py-4">
              <h2 className="font-display text-[19px] text-ink">The small print, in full</h2>
              <p className="mt-1 text-[13px] text-ink-2">
                Read to the bottom — the button below stays off until you have.
              </p>
            </div>
            <div
              ref={scrollRef}
              onScroll={onScroll}
              className="max-h-[320px] overflow-y-auto px-5 py-4"
            >
              {DISCLOSURES.map((d) => (
                <div key={d.id} className="mb-4">
                  <p className="text-[14.5px] font-medium text-ink">{d.heading}</p>
                  <p className="mt-1 text-[13.5px] leading-relaxed text-ink-2">{d.body}</p>
                </div>
              ))}
              <p className="mt-4 border-t border-line pt-4 text-[12.5px] leading-relaxed text-ink-2">
                {FRAUD_NOTICE}
              </p>
            </div>
          </section>

          <label className="mt-5 flex items-start gap-3 text-[14px] leading-relaxed text-ink">
            <input
              type="checkbox"
              checked={attested}
              disabled={!readToEnd}
              onChange={(e) => setAttested(e.target.checked)}
              className="mt-1"
            />
            <span className={readToEnd ? '' : 'text-ink-2'}>{ATTESTATION}</span>
          </label>

          <button
            type="button"
            className="pill-primary mt-4 w-full"
            disabled={!readToEnd || !attested || binding}
            onClick={bind}
          >
            {binding ? 'One moment…' : `Protect ${pet.name} for ${money(quote.totalMonthly)} a month`}
          </button>

          {bindNote && (
            <p className="mt-3 rounded-soft border border-line bg-cream/60 px-4 py-3 text-[13.5px] leading-relaxed text-ink">
              {bindNote}
            </p>
          )}

          <button
            type="button"
            className="mt-4 w-full text-[13.5px] text-forest text-action"
            onClick={() => setStep(1)}
          >
            Back to the price
          </button>
        </>
      )}
    </div>
  )
}
