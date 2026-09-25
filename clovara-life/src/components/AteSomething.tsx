import { useMemo, useState } from 'react'
import type { PetProfile } from '../data/types'
import { BAND_LABEL, bandFor, findToxins, NO_PLACES_COPY, NULL_PLACES_PROVIDER, type EmergencyVet } from '../engine/toxins'
import { forEmergency, placesFromEnv } from '../engine/places'
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
  'call-now': 'border-accent/40 bg-[#F6E8D2] text-amber',
  'vet-today': 'border-accent/40 bg-accent/12 text-amber',
  monitor: 'border-line bg-sage/50 text-deep',
}

export function AteSomething({ pet, onClose }: { pet: PetProfile; onClose: () => void }) {
  const places = useMemo(() => placesFromEnv() ?? NULL_PLACES_PROVIDER, [])
  const [vets, setVets] = useState<EmergencyVet[] | null>(null)
  const [vetState, setVetState] = useState<'idle' | 'asking' | 'done' | 'refused' | 'failed'>('idle')

  /**
   * Location is asked for only when somebody taps, never on load.
   *
   * A permission prompt that appears by itself is one people dismiss without
   * reading, and this screen must not spend its one chance at their attention
   * on a dialogue they did not ask for.
   */
  const findVets = () => {
    if (!navigator.geolocation) {
      setVetState('failed')
      return
    }
    setVetState('asking')
    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        try {
          const found = await places.findEmergencyVets({
            lat: pos.coords.latitude,
            lng: pos.coords.longitude,
          })
          setVets(forEmergency(found))
          setVetState('done')
          track('emergency_vets_found', { count: found.length, pet_is_demo: !!pet.demo })
        } catch {
          setVetState('failed')
        }
      },
      () => setVetState('refused'),
      { timeout: 10000, maximumAge: 60000 },
    )
  }

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
        <h1 className="font-display text-display-sm leading-tight text-ink">
          {pet.name} ate something
        </h1>
        <button type="button" onClick={onClose} className="pill-ghost px-4 py-2 text-body">
          Back
        </button>
      </div>

      {/* ── Before anything else ──────────────────────────────────────────── */}
      <section className="card border-l-[3px] border-l-accent bg-nudge-fill p-5">
        <p className="text-lead font-semibold leading-relaxed text-amber">
          {TOXIN_PRIMARY_INSTRUCTION}
        </p>
        <p className="mt-2.5 text-body-lg leading-relaxed text-ink">{TOXIN_NEVER_DIY}</p>
        <p className="mt-2.5 text-body-lg leading-relaxed text-ink">{TOXIN_TAKE_WITH_YOU}</p>

        <ul className="mt-4 space-y-2">
          {POISON_LINES.map((line) => (
            <li key={line.id}>
              <a
                href={`tel:${line.tel}`}
                onClick={() => track('poison_line_tapped', { line: line.id, pet_is_demo: !!pet.demo })}
                className="flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1 rounded-soft border border-line bg-white px-4 py-3"
              >
                <span className="text-body-lg font-medium text-ink">{line.name}</span>
                <span className="text-lead font-medium text-forest">{line.display}</span>
                <span className="w-full text-body-sm text-ink-2">
                  {line.region} · {line.note}
                </span>
              </a>
            </li>
          ))}
        </ul>

        {places.available ? (
          <div className="mt-4">
            {vetState === 'idle' && (
              <button
                type="button"
                className="pill-ghost w-full px-4 py-2.5 text-body-lg"
                onClick={findVets}
              >
                Find the nearest vet open now
              </button>
            )}
            {vetState === 'asking' && (
              <p className="text-body text-ink-2">Looking…</p>
            )}
            {vetState === 'refused' && (
              <p className="text-body leading-relaxed text-ink-2">
                Without your location we cannot look. Search for &ldquo;emergency vet near
                me&rdquo;, or ring a line above — they will tell you where to go.
              </p>
            )}
            {vetState === 'failed' && (
              <p className="text-body leading-relaxed text-ink-2">{NO_PLACES_COPY}</p>
            )}
            {vetState === 'done' && vets && (
              <>
                {vets.length === 0 ? (
                  <p className="text-body leading-relaxed text-ink-2">{NO_PLACES_COPY}</p>
                ) : (
                  <ul className="space-y-2">
                    {vets.map((v) => (
                      <li
                        key={`${v.name}-${v.address}`}
                        className="rounded-soft border border-line bg-white px-4 py-3"
                      >
                        <div className="flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1">
                          <span className="text-body-lg font-medium text-ink">{v.name}</span>
                          <span className="text-body-sm text-ink-2">
                            {v.openNow === true
                              ? 'Open now'
                              : v.openNow === false
                                ? 'Hours say closed'
                                : 'Hours unknown'}
                            {v.distanceKm !== undefined && ` · ${v.distanceKm}km`}
                          </span>
                        </div>
                        <p className="mt-0.5 text-body-sm leading-relaxed text-ink-2">{v.address}</p>
                        {v.tel && (
                          <a
                            href={`tel:${v.tel.replace(/\s+/g, '')}`}
                            onClick={() => track('emergency_vet_called', { pet_is_demo: !!pet.demo })}
                            className="mt-1 inline-block text-lead font-medium text-forest"
                          >
                            {v.tel}
                          </a>
                        )}
                      </li>
                    ))}
                  </ul>
                )}
                <p className="mt-2 text-body-sm leading-relaxed text-ink-2">
                  Opening hours come from Google and can be wrong at three in the morning. Ring
                  before you drive.
                </p>
              </>
            )}
          </div>
        ) : (
          <p className="mt-3 text-body-sm leading-relaxed text-ink-2">{NO_PLACES_COPY}</p>
        )}
      </section>

      {/* ── The lookup, second ────────────────────────────────────────────── */}
      <section className="card mt-5 overflow-hidden">
        <div className="border-b border-line bg-cream/50 px-5 py-4">
          <h2 className="font-display text-heading-sm text-ink">What did they eat?</h2>
          <p className="mt-1 text-body-sm leading-relaxed text-ink-2">
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
                    className="w-full py-3 text-left text-body-lg text-ink"
                  >
                    {t.name}
                  </button>
                </li>
              ))}
              {results.length === 0 && (
                <li className="py-3 text-body-lg leading-relaxed text-ink-2">
                  Not on our list. That does not mean it is safe — ring a poison line above and ask.
                </li>
              )}
            </ul>
          )}

          {picked && result && (
            <div className="mt-4">
              <p className="text-lead font-medium text-ink">{picked.name}</p>

              {picked.forms && !picked.alwaysCall && (
                <div className="mt-3 space-y-3">
                  <div className="flex flex-wrap gap-2">
                    {picked.forms.map((f) => (
                      <button
                        key={f.id}
                        type="button"
                        aria-pressed={formId === f.id}
                        onClick={() => setFormId(f.id)}
                        className={`rounded-full border-[1.5px] px-3.5 py-2 text-body transition ${
                          formId === f.id
                            ? 'border-forest bg-sage text-deep'
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
                <p className="font-display text-heading-sm leading-tight">{BAND_LABEL[result.band]}</p>
                <p className="mt-1 text-body-lg leading-relaxed">{result.because}</p>
              </div>

              <p className="mt-3 text-body-lg leading-relaxed text-ink">{picked.why}</p>
              <p className="mt-2 text-body leading-relaxed text-ink-2">
                <span className="font-medium text-ink">What you might see: </span>
                {picked.signs}
              </p>

              <button
                type="button"
                onClick={() => setPicked(null)}
                className="mt-4 text-body text-forest text-action"
              >
                Something else
              </button>
            </div>
          )}
        </div>

        <p className="border-t border-line bg-cream/40 px-5 py-4 text-body-sm leading-relaxed text-ink-2">
          {TOXIN_DISCLAIMER}
        </p>
      </section>
    </div>
  )
}
