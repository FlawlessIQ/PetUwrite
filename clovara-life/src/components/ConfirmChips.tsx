import { useState } from 'react'
import {
  EXTRACTION_ENABLED,
  confirm,
  extractionProvider,
  ordered,
  type Candidate,
  type ConfirmedField,
} from '../extract/provider'
import { track } from '../analytics/track'

/**
 * Confirm-chips (SPEC §4.3, invariant 8).
 *
 * The only path from a document to a pet's record, and it runs through a
 * person. Every candidate is shown with the text it came from, and nothing is
 * stored until somebody taps yes.
 *
 * CONFIDENCE IS NEVER SHOWN. An extractor's score rendered as "94%" invites an
 * owner to trust the high ones without reading them, which is the exact failure
 * invariant 8 exists to prevent. It orders the list and nothing else.
 *
 * REJECT IS AS PROMINENT AS CONFIRM. A chip flow where "yes" is a big green
 * button and "no" is a grey link is a flow that collects agreement rather than
 * confirmation.
 */
export function ConfirmChips({
  candidates,
  unavailableReason,
  onConfirmed,
}: {
  candidates: Candidate[]
  unavailableReason?: string
  onConfirmed: (fields: ConfirmedField[]) => void
}) {
  const [pending, setPending] = useState<Candidate[]>(() => ordered(candidates))
  const [kept, setKept] = useState<ConfirmedField[]>([])

  if (!EXTRACTION_ENABLED || !extractionProvider().available) {
    return (
      <section className="card p-5" aria-labelledby="chips-heading">
        <h2 id="chips-heading" className="font-display text-heading-sm text-ink">
          Reading vet records
        </h2>
        <p className="mt-2 text-body-lg leading-relaxed text-ink-2">
          {unavailableReason ??
            'Not switched on yet. It needs a security review of how those documents are stored, which is booked separately — we would rather not hold them at all than hold them badly.'}
        </p>
      </section>
    )
  }

  const decide = (c: Candidate, keep: boolean) => {
    setPending((p) => p.filter((x) => x.id !== c.id))
    track('extraction_chip', { kind: c.kind, kept: keep })
    if (!keep) return
    const field = confirm(c, new Date())
    setKept((k) => {
      const next = [...k, field]
      onConfirmed(next)
      return next
    })
  }

  return (
    <section className="card overflow-hidden" aria-labelledby="chips-heading">
      <div className="border-b border-line bg-cream/50 px-5 py-4">
        <h2 id="chips-heading" className="font-display text-heading-sm text-ink">
          Is this right?
        </h2>
        <p className="mt-1 text-body leading-relaxed text-ink-2">
          We read this off the page. Nothing is saved until you say it is correct, and anything you
          are unsure about is better left out.
        </p>
      </div>

      {pending.length === 0 ? (
        <p className="px-5 py-5 text-body-lg text-ink-2">
          {kept.length > 0 ? 'Saved. Thank you.' : 'Nothing left to check.'}
        </p>
      ) : (
        <ul className="divide-y divide-line">
          {pending.map((c) => (
            <li key={c.id} className="px-5 py-4">
              <p className="text-lead text-ink">{c.label}</p>
              <p className="mt-1 text-body-sm leading-relaxed text-ink-2">
                Read from: &ldquo;{c.sourceText}&rdquo;
              </p>
              <div className="mt-3 flex flex-wrap gap-2">
                <button
                  type="button"
                  className="pill-ghost px-4 py-2 text-body"
                  onClick={() => decide(c, true)}
                >
                  Yes, that is right
                </button>
                <button
                  type="button"
                  className="pill-ghost px-4 py-2 text-body"
                  onClick={() => decide(c, false)}
                >
                  No, leave it out
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}
    </section>
  )
}
