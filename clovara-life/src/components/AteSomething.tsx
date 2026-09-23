import { useMemo, useState } from 'react'
import type { PetProfile } from '../data/types'
import { BAND_LABEL, bandFor, findToxins, NO_PLACES_COPY, NULL_PLACES_PROVIDER } from '../engine/toxins'
import {
  POISON_LINES,
  TOXIN_DISCLAIMER,
  TOXIN_NEVER_DIY,
  TOXIN_PRIMARY_INSTRUCTION,
  TOXIN_TAKE_WITH_YOU,
  type RiskBand,
  type Toxin,
} from '../data/toxins'
import { track } from '../analytics/track'

/**
 * "He ate a grape" (SPEC §6.5).
 *
 * THE ORDER OF THIS SCREEN IS THE DESIGN. Somebody arriving here is frightened
 * and will read the first thing and act on it, so the phone numbers and the
 * "do not make them sick" line come BEFORE the lookup. The calculator is the
 * least important thing on the page: its only job is to stop somebody who has
 * decided a small piece of chocolate is fine from being right by accident.
 *
 * Nothing here is ever a clearance. The best outcome the banding offers is
 * "watch closely, and ring if anything changes".
 */
const BAND_STYLE: Record<RiskBand, string> = {
  'call-now': 'border-[#B3261E]/35 bg-[#B3261E]/10 text-[#8C1D18]',
  'vet-today': 'border-accent/40 bg-accent/12 text-[#8A5510]',
  monitor: 'border-line bg-sage/50 text-deep',
}

export function AteSomething({ pet, onClose }: { pet: PetProfile; onClose: () => void }) {
  const [query, setQuery] = useState('')
  const [picked, setPicked] = useState<Toxin | null>(null)
  const [formId, setFormId] = useState<string | undefined>()
  const [grams, setGrams] = useState('')

  const results = useMemo(() => findToxins(query, pet.species), [query, pet.species])
  const result = picked
    ? bandFor(picked, pet, { formId, grams: grams ? Number(grams) : undefined })
    : null

  const choose = (t: Toxin) => {
    setPicked(t)
    setFormId(t.forms?.[0]?.id)
    setGrams('')
    track('toxin_lookup', { toxin: t.id, pet_is_demo: !!pet.demo, species: pet.species })
  }

  return (
    <div className="mx-auto w-full max-w-[760px] px-5 pb-24 pt-6">
      <div className="mb-4 flex items-center justify-between gap-3">
        <h1 className="font-display text-[26px] leading-tight text-ink">
          {pet.name} ate something
        </h1>
        <button type="button" onClick={onClose} className="pill-ghost px-4 py-2 text-[13.5px]">
          Back
        </button>
      </div>

      {/* ── Before anything else ──────────────────────────────────────────── */}
      <section className="card border-[#B3261E]/30 bg-[#B3261E]/[0.06] p-5">
        <p className="text-[15.5px] font-medium leading-relaxed text-[#8C1D18]">
          {TOXIN_PRIMARY_INSTRUCTION}
        </p>
        <p className="mt-2.5 text-[14px] leading-relaxed text-[#8C1D18]">{TOXIN_NEVER_DIY}</p>
        <p className="mt-2.5 text-[14px] leading-relaxed text-ink">{TOXIN_TAKE_WITH_YOU}</p>

        <ul className="mt-4 space-y-2">
          {POISON_LINES.map((line) => (
            <li key={line.id}>
              <a
                href={`tel:${line.tel}`}
                onClick={() => track('poison_line_tapped', { line: line.id, pet_is_demo: !!pet.demo })}
                className="flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1 rounded-soft border border-line bg-white px-4 py-3"
              >
                <span className="text-[14.5px] font-medium text-ink">{line.name}</span>
                <span className="text-[15px] font-medium text-forest">{line.display}</span>
                <span className="w-full text-[12.5px] text-muted">
                  {line.region} · {line.note}
                </span>
              </a>
            </li>
          ))}
        </ul>

        {!NULL_PLACES_PROVIDER.available && (
          <p className="mt-3 text-[13px] leading-relaxed text-muted">{NO_PLACES_COPY}</p>
        )}
      </section>

      {/* ── The lookup, second ────────────────────────────────────────────── */}
      <section className="card mt-5 overflow-hidden">
        <div className="border-b border-line bg-cream/50 px-5 py-4">
          <h2 className="font-display text-[19px] text-ink">What did they eat?</h2>
          <p className="mt-1 text-[13px] leading-relaxed text-muted">
            This tells you how urgent it is. It never tells you it is fine.
          </p>
        </div>

        <div className="px-5 py-4">
          <label className="sr-only" htmlFor="toxin-q">
            Search what they ate
          </label>
          <input
            id="toxin-q"
            type="search"
            className="field"
            placeholder="grapes, chocolate, ibuprofen…"
            value={query}
            onChange={(e) => {
              setQuery(e.target.value)
              setPicked(null)
            }}
          />

          {!picked && (
            <ul className="mt-3 divide-y divide-line">
              {results.map((t) => (
                <li key={t.id}>
                  <button
                    type="button"
                    onClick={() => choose(t)}
                    className="w-full py-3 text-left text-[14.5px] text-ink"
                  >
                    {t.name}
                  </button>
                </li>
              ))}
              {results.length === 0 && (
                <li className="py-3 text-[14px] leading-relaxed text-muted">
                  Not on our list. That does not mean it is safe — ring a poison line above and ask.
                </li>
              )}
            </ul>
          )}

          {picked && result && (
            <div className="mt-4">
              <p className="text-[15px] font-medium text-ink">{picked.name}</p>

              {picked.forms && !picked.alwaysCall && (
                <div className="mt-3 space-y-3">
                  <div className="flex flex-wrap gap-2">
                    {picked.forms.map((f) => (
                      <button
                        key={f.id}
                        type="button"
                        aria-pressed={formId === f.id}
                        onClick={() => setFormId(f.id)}
                        className={`rounded-full border px-3.5 py-2 text-[13.5px] transition ${
                          formId === f.id
                            ? 'border-forest bg-forest text-white'
                            : 'border-line bg-white text-ink'
                        }`}
                      >
                        {f.label}
                      </button>
                    ))}
                  </div>
                  <div>
                    <label htmlFor="toxin-g" className="label">
                      Roughly how many grams?
                    </label>
                    <input
                      id="toxin-g"
                      type="number"
                      min="0"
                      inputMode="decimal"
                      className="field mt-1.5 max-w-[200px]"
                      placeholder="a guess is fine"
                      value={grams}
                      onChange={(e) => setGrams(e.target.value)}
                    />
                  </div>
                </div>
              )}

              <div className={`mt-4 rounded-soft border px-4 py-3.5 ${BAND_STYLE[result.band]}`}>
                <p className="font-display text-[19px] leading-tight">{BAND_LABEL[result.band]}</p>
                <p className="mt-1 text-[14px] leading-relaxed">{result.because}</p>
              </div>

              <p className="mt-3 text-[14px] leading-relaxed text-ink">{picked.why}</p>
              <p className="mt-2 text-[13.5px] leading-relaxed text-muted">
                <span className="font-medium text-ink">What you might see: </span>
                {picked.signs}
              </p>

              <button
                type="button"
                onClick={() => setPicked(null)}
                className="mt-4 text-[13.5px] text-forest underline underline-offset-2"
              >
                Something else
              </button>
            </div>
          )}
        </div>

        <p className="border-t border-line bg-cream/40 px-5 py-4 text-[12.5px] leading-relaxed text-muted">
          {TOXIN_DISCLAIMER}
        </p>
      </section>
    </div>
  )
}
