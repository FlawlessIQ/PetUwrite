import { useMemo, useState } from 'react'
import type { PetProfile, Projection } from '../data/types'
import { buildVisitSummary, summaryAsText, type Told } from '../engine/visitSummary'
import { track } from '../analytics/track'

/**
 * C0 — the summary for a vet visit (SPEC-COMPANION §9).
 *
 * COPY IS THE PRIMARY ACTION, not print and not a card. A practice system takes
 * pasted text; it does not take a screenshot, and an owner reading aloud from a
 * phone while holding a frightened animal is the thing this exists to replace.
 *
 * The caveats are at the top on screen and at the bottom of the text. On screen
 * a vet reads down and should meet "none of this is verified" before the facts;
 * in a pasted note the convention is notes last, and fighting it would get the
 * paste mangled.
 */
const TOLD_STYLE: Record<Told, string> = {
  'owner said': 'text-ink-2',
  'from a document': 'text-deep',
  'not asked': 'text-ink-2/70 italic',
}

export function VisitSummary({
  pet,
  projection,
  now = new Date(),
}: {
  pet: PetProfile
  projection: Projection
  now?: Date
}) {
  const summary = useMemo(() => buildVisitSummary(pet, projection, now), [pet, projection, now])
  const [copied, setCopied] = useState(false)
  const [open, setOpen] = useState(false)

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(summaryAsText(summary))
      setCopied(true)
      track('visit_summary_copied', { pet_is_demo: !!pet.demo, species: pet.species })
      setTimeout(() => setCopied(false), 3000)
    } catch {
      // Clipboard refused. The text is on screen once expanded, to select by hand.
      setOpen(true)
    }
  }

  return (
    <section className="card overflow-hidden" aria-labelledby="visit-heading">
      <div className="border-b border-line bg-cream/50 px-5 py-4">
        <p className="label">For the vet</p>
        <h2 id="visit-heading" className="mt-1 font-display text-[20px] text-ink">
          Everything about {pet.name}, on one page
        </h2>
        <p className="mt-1 text-[13.5px] leading-relaxed text-ink-2">
          What you would be asked in the room and would not remember. Copy it, send it ahead, or
          read it off your phone.
        </p>
      </div>

      <div className="px-5 py-5">
        <p className="rounded-soft border border-accent/30 bg-accent/10 px-4 py-3 text-[13px] leading-relaxed text-[#8A5510]">
          Everything below was reported by you through this app. None of it has been examined or
          verified by a vet, and a blank means the question was never asked — not that the answer is
          no.
        </p>

        <div className="mt-4 flex flex-wrap gap-2">
          <button type="button" className="pill-primary px-5 py-2.5 text-[14px]" onClick={copy}>
            {copied ? 'Copied' : 'Copy for the vet'}
          </button>
          <button
            type="button"
            className="pill-ghost px-5 py-2.5 text-[14px]"
            onClick={() => setOpen((o) => !o)}
            aria-expanded={open}
          >
            {open ? 'Hide it' : 'Read it first'}
          </button>
        </div>

        {open && (
          <div className="mt-5 space-y-5">
            {summary.sections.map((s) => (
              <div key={s.heading}>
                <p className="label">{s.heading}</p>
                {s.lines.length === 0 ? (
                  <p className="mt-1.5 text-[13.5px] leading-relaxed text-ink-2">{s.emptyNote}</p>
                ) : (
                  <ul className="mt-1.5 divide-y divide-line border-t border-line">
                    {s.lines.map((l) => (
                      <li key={l.label} className="py-2">
                        <div className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-0.5">
                          <span className="text-[14.5px] text-ink">{l.label}</span>
                          <span className={`text-[13px] ${TOLD_STYLE[l.told]}`}>{l.told}</span>
                        </div>
                        <p className="mt-0.5 text-[13.5px] leading-relaxed text-ink-2">{l.value}</p>
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            ))}

            <div>
              <p className="label">Notes that travel with it</p>
              <ul className="mt-1.5 space-y-1.5">
                {summary.caveats.map((c) => (
                  <li key={c} className="text-[13px] leading-relaxed text-ink-2">
                    {c}
                  </li>
                ))}
              </ul>
            </div>
          </div>
        )}
      </div>
    </section>
  )
}
