import { useState } from 'react'
import type { PetProfile } from '../data/types'
import { firstNightState } from '../engine/firstNight'
import { FIRST_NIGHT_ESCALATION, FIRST_NIGHT_FOOTER } from '../data/firstNight'

/**
 * First-Night Mode (SPEC §6.2) — the first seventy-two hours.
 *
 * Designed for 2am on a phone, which drives every decision here: the block you
 * are in is open, everything else is collapsed, and the escalation list is
 * always visible rather than behind a tap. Somebody frightened at three in the
 * morning should not have to expand anything to find out whether to ring
 * somebody.
 */
export function FirstNight({ pet, now = new Date() }: { pet: PetProfile; now?: Date }) {
  const state = firstNightState(pet, now)
  const [openId, setOpenId] = useState<string | null>(null)

  if (!state.active || !state.current) return null
  const { current, upcoming, hoursHome } = state

  return (
    <section className="card overflow-hidden" aria-labelledby="first-night-heading">
      <div className="border-b border-line bg-cream/50 px-5 py-4">
        <p className="label">First nights</p>
        <h2 id="first-night-heading" className="mt-1 font-display text-[20px] text-ink">
          {current.title}
        </h2>
        <p className="mt-1 text-[13.5px] text-ink-2">
          {pet.name} has been home about {Math.max(1, Math.round(hoursHome))} hour
          {Math.round(hoursHome) === 1 ? '' : 's'}.
        </p>
      </div>

      <div className="px-5 py-5">
        <p className="text-[15px] leading-relaxed text-ink">{current.body}</p>

        <ul className="mt-4 space-y-2.5">
          {current.doNow.map((item) => (
            <li key={item} className="flex gap-3 text-[14.5px] leading-relaxed text-ink">
              <span aria-hidden="true" className="mt-[7px] h-1.5 w-1.5 shrink-0 rounded-full bg-forest" />
              <span>{item}</span>
            </li>
          ))}
        </ul>

        <p className="mt-4 rounded-soft bg-sage/60 px-4 py-3 text-[14px] leading-relaxed text-deep">
          <span className="font-medium">Normal right now: </span>
          {current.normal}
        </p>

        {/* Never behind a tap. */}
        <p className="mt-3 rounded-soft border border-accent/30 bg-accent/10 px-4 py-3 text-[14px] leading-relaxed text-[#8A5510]">
          {FIRST_NIGHT_ESCALATION}
        </p>

        {upcoming.length > 0 && (
          <div className="mt-5">
            <p className="label">What comes next</p>
            <ul className="mt-2 divide-y divide-line border-t border-line">
              {upcoming.map((b) => {
                const open = openId === b.id
                return (
                  <li key={b.id}>
                    <button
                      type="button"
                      aria-expanded={open}
                      onClick={() => setOpenId(open ? null : b.id)}
                      className="flex w-full items-center justify-between gap-4 py-3 text-left"
                    >
                      <span className="text-[14.5px] text-ink">{b.title}</span>
                      <span
                        aria-hidden="true"
                        className={`shrink-0 text-[18px] leading-none text-ink-2 transition-transform ${open ? 'rotate-45' : ''}`}
                      >
                        +
                      </span>
                    </button>
                    {open && (
                      <div className="pb-4">
                        <p className="text-[14px] leading-relaxed text-ink-2">{b.body}</p>
                        <p className="mt-2 text-[13.5px] leading-relaxed text-deep">
                          <span className="font-medium">Normal: </span>
                          {b.normal}
                        </p>
                      </div>
                    )}
                  </li>
                )
              })}
            </ul>
          </div>
        )}

        <p className="mt-5 text-[12.5px] leading-relaxed text-ink-2">{FIRST_NIGHT_FOOTER}</p>
      </div>
    </section>
  )
}
