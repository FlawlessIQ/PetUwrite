import { useMemo, useState } from 'react'
import type { PetProfile } from '../data/types'
import { projectionShift, reviewItems } from '../engine/review'
import { track } from '../analytics/track'

/**
 * The annual re-projection (SPEC §4.3): "anything change this year?"
 *
 * Two things at once — the yearly chance to correct facts that drift, and the
 * moment the projection is honestly restated a year on.
 *
 * IT DOES NOT ASK THE QUESTIONS ITSELF. Each item offers "still true" or "this
 * changed", and "this changed" opens the question that already exists below in
 * Sharpen. One place renders a question, which is the only way the ask registry
 * can enforce anything — a second set of pickers here would be a second set to
 * keep honest, and the first one to drift.
 *
 * TONE. A year on, the number has usually gone down: the animal is a year
 * older. That is not a failure and this screen must not read like one. It says
 * what moved and why, and never implies the owner could have prevented the
 * passage of time.
 */
export function AnnualReview({
  pet,
  currentRange,
  onRevisit,
  onComplete,
  onDismiss,
}: {
  pet: PetProfile
  currentRange: { low: number; high: number }
  /** Open this question in Sharpen. */
  onRevisit: (field: string) => void
  onComplete: (patch: Partial<PetProfile>) => void
  onDismiss: () => void
}) {
  const items = useMemo(() => reviewItems(pet), [pet])
  const [handled, setHandled] = useState<Set<string>>(() => new Set())
  const allHandled = items.every((i) => handled.has(i.field))

  const lastYear = pet.lastReviewedRange
  const shift = lastYear ? projectionShift(lastYear, currentRange) : null

  const mark = (field: string, changed: boolean) => {
    setHandled((prev) => new Set(prev).add(field))
    track('tier1_field_added', {
      field,
      pet_is_demo: !!pet.demo,
      species: pet.species,
      // Confirming "still true" is a real answer and a real piece of upkeep.
      // Recording it the same way as a change would make the yearly review look
      // like a burst of new data every twelve months, which it is not.
      review_confirmed: !changed,
    })
    if (changed) onRevisit(field)
  }

  const finish = () => {
    onComplete({
      lastReviewedAt: new Date().toISOString(),
      lastReviewedRange: { low: currentRange.low, high: currentRange.high },
    })
  }

  return (
    <section className="card overflow-hidden" aria-labelledby="review-heading">
      <div className="border-b border-line bg-cream/50 px-5 py-4">
        <h2 id="review-heading" className="font-display text-heading text-ink">
          A year with {pet.name}
        </h2>
        {shift && !shift.unchanged ? (
          <p className="mt-1 text-body-lg leading-relaxed text-ink-2">
            Last year we said {lastYear!.low.toFixed(1)}–{lastYear!.high.toFixed(1)} healthy years.
            Today it is {currentRange.low.toFixed(1)}–{currentRange.high.toFixed(1)} — {pet.name} is
            a year older, and the range moves with them.
          </p>
        ) : (
          <p className="mt-1 text-body-lg leading-relaxed text-ink-2">
            A once-a-year check of the handful of things that actually change. Every question is
            optional, and "still true" is the most common answer.
          </p>
        )}
      </div>

      <ul className="divide-y divide-line">
        {items.map((item) => {
          const done = handled.has(item.field)
          return (
            <li key={item.field} className={`px-5 py-4 ${done ? 'opacity-55' : ''}`}>
              <div className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1">
                <p className="text-lead font-medium text-ink">{item.prompt}</p>
                <p className="text-body-sm text-ink-2">{item.current}</p>
              </div>
              <p className="mt-1 text-body-sm leading-relaxed text-ink-2">{item.because}</p>
              {done ? (
                <p className="mt-2 text-body-sm text-forest">Thank you — noted.</p>
              ) : (
                <div className="mt-3 flex flex-wrap gap-2">
                  <button
                    type="button"
                    className="pill-ghost px-4 py-2 text-body-lg"
                    onClick={() => mark(item.field, false)}
                  >
                    Still true
                  </button>
                  <button
                    type="button"
                    className="pill-ghost px-4 py-2 text-body-lg"
                    onClick={() => mark(item.field, true)}
                  >
                    This changed
                  </button>
                </div>
              )}
            </li>
          )
        })}
      </ul>

      <div className="flex flex-wrap items-center justify-between gap-3 border-t border-line bg-cream/40 px-5 py-4">
        <p className="text-body-sm text-ink-2">
          {allHandled
            ? 'That is everything. We will ask again next year.'
            : `${items.filter((i) => !handled.has(i.field)).length} left, none of them required.`}
        </p>
        <div className="flex gap-2">
          <button type="button" className="pill-ghost px-4 py-2 text-body-lg" onClick={onDismiss}>
            Not now
          </button>
          <button
            type="button"
            className="pill-primary px-4 py-2 text-body-lg"
            onClick={finish}
            disabled={!allHandled}
          >
            Done
          </button>
        </div>
      </div>
    </section>
  )
}
