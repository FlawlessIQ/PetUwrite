import { useMemo } from 'react'
import type { PetProfile, Projection } from '../data/types'
import { buildBriefing, NULL_ENVIRONMENT } from '../engine/briefing'

/**
 * The morning briefing (SPEC-HORIZON §1.2).
 *
 * Renders in the app. Email delivery is off pending a consent decision — a
 * daily email is a different thing to agree to from a monthly one.
 *
 * THE EMPTY STATE IS THE FEATURE, not a fallback. "Nothing needs doing for
 * Scout today" is the most common true answer and it is shown as plainly as a
 * busy morning would be. A briefing that finds something to say every day is
 * one people stop reading, and they stop reading it before the day it matters.
 */
export function Briefing({
  pet,
  projection,
  now = new Date(),
}: {
  pet: PetProfile
  projection: Projection
  now?: Date
}) {
  // No environment provider is chosen, so there is simply no weather line.
  const briefing = useMemo(
    () => buildBriefing(pet, projection, now, undefined),
    [pet, projection, now],
  )

  if (briefing.items.length === 0 && !briefing.nothingToSay) return null

  const today = now.toLocaleDateString('en-GB', { weekday: 'long' })

  return (
    <section className="card overflow-hidden" aria-labelledby="briefing-heading">
      <div className="border-b border-line bg-cream/50 px-5 py-4">
        <p className="label">{today}</p>
        <h2 id="briefing-heading" className="mt-1 font-display text-[20px] text-ink">
          {briefing.items.some((i) => i.actionable)
            ? `${pet.name} today`
            : `${pet.name} is all set`}
        </h2>
      </div>

      <div className="px-5 py-5">
        {briefing.nothingToSay ? (
          <p className="text-[15px] leading-relaxed text-ink">{briefing.nothingToSay}</p>
        ) : (
          <ul className="space-y-3">
            {briefing.items.map((item) => (
              <li key={item.id} className="flex gap-3">
                <span
                  aria-hidden="true"
                  className={`mt-[7px] h-1.5 w-1.5 shrink-0 rounded-full ${
                    item.actionable ? 'bg-forest' : 'bg-line'
                  }`}
                />
                <span className="text-[15px] leading-relaxed text-ink">{item.text}</span>
              </li>
            ))}
          </ul>
        )}

        {!NULL_ENVIRONMENT.available && (
          <p className="mt-4 text-[12px] leading-relaxed text-ink-2">
            No weather or pollen here yet — there is no provider connected, and we would rather say
            one fewer thing than guess at it.
          </p>
        )}
      </div>
    </section>
  )
}
