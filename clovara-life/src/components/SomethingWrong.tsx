import { useEffect, useRef, useState } from 'react'
import type { PetProfile } from '../data/types'
import { classify, flagsFor } from '../engine/safety'
import {
  NO_FLAG_BODY,
  NO_FLAG_HEADLINE,
  RED_FLAGS_REVIEW_STATUS,
  RED_FLAG_BODY,
  RED_FLAG_HEADLINE,
} from '../data/redFlags'
import { POISON_LINES } from '../data/toxins'
import { track } from '../analytics/track'
import { FindVet } from './FindVet'

/**
 * C1 — "something is wrong" (SPEC-COMPANION §3.1, §9).
 *
 * No model. Somebody describes what they are seeing, a deterministic classifier
 * checks it against the red-flag list, and the answer is either "ring now" or
 * an honest statement that our list did not recognise anything.
 *
 * THE SECOND ANSWER IS THE DANGEROUS ONE and most of the care here goes into
 * it. "Nothing matched" is a fact about our list, not about the animal, and the
 * page says so in those words — an owner who reads it as "sounds fine" and goes
 * to bed is the failure this surface exists to prevent. It also shows the list
 * itself, because what we check for is only meaningful next to what we do not.
 */
export function SomethingWrong({ pet, onClose }: { pet: PetProfile; onClose: () => void }) {
  const [text, setText] = useState('')
  const [result, setResult] = useState<ReturnType<typeof classify> | null>(null)
  const [showList, setShowList] = useState(false)
  /**
   * The answer's heading, which takes focus after every check (UAT run 2, N3).
   *
   * The answer used to appear below the box with nothing to say so: on a phone
   * with the keyboard still up, "Stop and ring a vet now" could be behind it,
   * and a screen reader was not told anything had happened. Focusing the
   * heading does all three — brings it into view, dismisses the keyboard, and
   * reads it out. `checks` re-runs it when the same answer comes back twice.
   */
  const answerRef = useRef<HTMLHeadingElement>(null)
  const [checks, setChecks] = useState(0)
  useEffect(() => {
    const h = answerRef.current
    if (!h || checks === 0) return
    h.focus({ preventScroll: true })
    h.scrollIntoView({ block: 'start' })
  }, [checks])

  const check = () => {
    const r = classify(text, pet.species)
    setResult(r)
    setChecks((n) => n + 1)
    track('safety_check', {
      escalated: r.escalate,
      matched: r.matched.length,
      pet_is_demo: !!pet.demo,
      species: pet.species,
    })
  }

  return (
    <div className="mx-auto w-full max-w-[720px] px-5 pb-24 pt-6">
      <div className="mb-4 flex items-center justify-between gap-3">
        <h1 className="font-display text-display-sm leading-tight text-ink">
          Something is wrong with {pet.name}
        </h1>
        <button type="button" onClick={onClose} className="pill-ghost px-4 py-2 text-body">
          Back
        </button>
      </div>

      <section className="card p-5">
        <label htmlFor="wrong" className="text-lead leading-relaxed text-ink">
          What are you seeing? Write it how you would say it.
        </label>
        <textarea
          id="wrong"
          rows={4}
          className="field mt-3 resize-none"
          placeholder="He has been quiet since this morning and his gums look pale…"
          value={text}
          onChange={(e) => {
            setText(e.target.value)
            setResult(null)
          }}
        />
        <button
          type="button"
          className="pill-primary mt-3 w-full"
          onClick={check}
          disabled={!text.trim()}
        >
          Check it
        </button>
        <p className="mt-3 text-body-sm leading-relaxed text-ink-2">
          This checks a short list of signs that always need a vet straight away. It is not a
          diagnosis and it cannot examine {pet.name}.
        </p>
      </section>

      {result?.escalate && (
        <section className="card mt-5 border-l-[3px] border-l-accent bg-nudge-fill p-5">
          <h2
            ref={answerRef}
            tabIndex={-1}
            className="scroll-mt-20 font-display text-heading-lg leading-tight text-amber focus:outline-none"
          >
            {RED_FLAG_HEADLINE}
          </h2>
          <p className="mt-2 text-body-lg leading-relaxed text-ink">{RED_FLAG_BODY}</p>

          <ul className="mt-4 space-y-2.5">
            {result.matched.map((f) => (
              <li key={f.id} className="rounded-soft border border-line bg-white px-4 py-3">
                <p className="text-body-lg font-medium text-ink">{f.label}</p>
                <p className="mt-0.5 text-body-sm leading-relaxed text-ink-2">{f.because}</p>
              </li>
            ))}
          </ul>

          <ul className="mt-4 space-y-2">
            {POISON_LINES.map((l) => (
              <li key={l.id}>
                <a
                  href={`tel:${l.tel}`}
                  onClick={() => track('poison_line_tapped', { line: l.id, pet_is_demo: !!pet.demo })}
                  className="flex flex-wrap items-baseline justify-between gap-x-3 rounded-soft border border-line bg-white px-4 py-3"
                >
                  <span className="text-body-lg font-medium text-ink">{l.name}</span>
                  <span className="text-lead font-medium text-forest">{l.display}</span>
                </a>
              </li>
            ))}
          </ul>
          <p className="mt-3 text-body-sm leading-relaxed text-ink-2">
            Poison lines can also tell you where your nearest emergency practice is.
          </p>
          <FindVet pet={pet} />
        </section>
      )}

      {result && !result.escalate && (
        <section className="card mt-5 p-5">
          <h2
            ref={answerRef}
            tabIndex={-1}
            className="scroll-mt-20 font-display text-heading leading-tight text-ink focus:outline-none"
          >
            {NO_FLAG_HEADLINE}
          </h2>
          <p className="mt-2 text-body-lg leading-relaxed text-ink">{NO_FLAG_BODY}</p>
          <button
            type="button"
            onClick={() => setShowList((v) => !v)}
            aria-expanded={showList}
            className="mt-3 text-action text-body text-forest"
          >
            {showList ? 'Hide what we check for' : `See all ${result.consideredCount} things we check for`}
          </button>
          {showList && (
            <ul className="mt-3 divide-y divide-line border-t border-line">
              {flagsFor(pet.species).map((f) => (
                <li key={f.id} className="py-2.5">
                  <p className="text-body-lg text-ink">{f.label}</p>
                  <p className="mt-0.5 text-body-sm leading-relaxed text-ink-2">{f.because}</p>
                </li>
              ))}
            </ul>
          )}
        </section>
      )}

      <p className="mt-5 text-body-sm leading-relaxed text-ink-2">
        {/* The status stays on the page, deliberately (verify-safety), but in
            words: "VET-REVIEW:" read as an internal tag (UAT run 1, D16). */}
        {RED_FLAGS_REVIEW_STATUS === 'VET-REVIEW' ? 'Still being reviewed by a vet' : 'Reviewed by a vet'}: this
        list is written to send you to a vet more often than strictly necessary rather than less.
      </p>
    </div>
  )
}
