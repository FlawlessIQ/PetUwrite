import { useMemo, useState } from 'react'
import type { PetProfile, Projection } from '../data/types'
import { seniorState } from '../engine/senior'
import { MENTION_NOTE, NO_SCALE_NOTE, SENIOR_OPENING } from '../data/senior'

/**
 * The senior suite (SPEC-HORIZON §1.5).
 *
 * Assembly over what the engine already knows, plus the house-changes that are
 * husbandry rather than medicine.
 *
 * NO NUMBER ANYWHERE. No quality-of-life score, no remaining time, no "X% of
 * the way through". The page is a list of rugs and ramps and six things worth
 * saying at the next appointment, and it stays that.
 */
export function SeniorSuite({
  pet,
  projection,
}: {
  pet: PetProfile
  projection: Projection
}) {
  const state = useMemo(() => seniorState(pet, projection), [pet, projection])
  const [open, setOpen] = useState<string | null>(null)

  if (!state.visible) return null

  return (
    <section className="card overflow-hidden" aria-labelledby="senior-heading">
      <div className="border-b border-line bg-cream/50 px-5 py-4">
        <p className="label">{state.stageLabel}</p>
        <h2 id="senior-heading" className="mt-1 font-display text-[20px] text-ink">
          Making the house easier for {pet.name}
        </h2>
        <p className="mt-1.5 text-[13.5px] leading-relaxed text-ink-2">{SENIOR_OPENING}</p>
      </div>

      <div className="px-5 py-5">
        <p className="text-[14.5px] leading-relaxed text-ink">{state.stageSummary}</p>

        {/* ── What to change ─────────────────────────────────────────── */}
        <p className="label mt-5">Around the house</p>
        <ul className="mt-2 divide-y divide-line border-t border-line">
          {state.adaptations.map((a) => {
            const isOpen = open === a.id
            return (
              <li key={a.id}>
                <button
                  type="button"
                  aria-expanded={isOpen}
                  onClick={() => setOpen(isOpen ? null : a.id)}
                  className="flex w-full items-center justify-between gap-4 py-3 text-left"
                >
                  <span className="text-[14.5px] text-ink">{a.what}</span>
                  <span
                    aria-hidden="true"
                    className={`shrink-0 text-[18px] leading-none text-ink-2 transition-transform ${isOpen ? 'rotate-45' : ''}`}
                  >
                    +
                  </span>
                </button>
                {isOpen && (
                  <p className="pb-3.5 text-[13.5px] leading-relaxed text-ink-2">{a.why}</p>
                )}
              </li>
            )
          })}
        </ul>

        {/* ── What a vet cannot see ──────────────────────────────────── */}
        <p className="label mt-6">Worth mentioning at the next visit</p>
        <ul className="mt-2 space-y-2">
          {state.worthMentioning.map((m) => (
            <li key={m} className="flex gap-3 text-[14px] leading-relaxed text-ink">
              <span aria-hidden="true" className="mt-[7px] h-1.5 w-1.5 shrink-0 rounded-full bg-line" />
              <span>{m}</span>
            </li>
          ))}
        </ul>
        <p className="mt-3 text-[12.5px] leading-relaxed text-ink-2">{MENTION_NOTE}</p>

        {/* ── What the plan already says for this stage ──────────────── */}
        {state.careActions.length > 0 && (
          <>
            <p className="label mt-6">What the plan already says</p>
            <ul className="mt-2 space-y-2">
              {state.careActions.map((c) => (
                <li key={c} className="text-[14px] leading-relaxed text-ink">
                  {c}
                </li>
              ))}
            </ul>
          </>
        )}

        {state.openNow.length > 0 && (
          <>
            <p className="label mt-6">Already on the record</p>
            <ul className="mt-2 space-y-1.5">
              {state.openNow.map((c) => (
                <li key={c.id} className="text-[14px] leading-relaxed text-ink">
                  {c.name}
                </li>
              ))}
            </ul>
          </>
        )}

        <p className="mt-6 border-t border-line pt-4 text-[12.5px] leading-relaxed text-ink-2">
          {NO_SCALE_NOTE}
        </p>
      </div>
    </section>
  )
}
