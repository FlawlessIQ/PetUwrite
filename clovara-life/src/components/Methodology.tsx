import { useState } from 'react'
import type { Projection } from '../data/types'
import { EVIDENCE_LABELS, NEUTER_AGE_CITATION, NEUTER_CITATIONS, STAGE_CITATIONS } from '../data/engine'

const CONFIDENCE_COPY = {
  published: 'A breed-level figure for this breed exists in the study cited below.',
  derived:
    'A published figure exists but measures something that does not transfer directly to a US pet at home, so the range was composed from it and the published size-class figure.',
  illustrative:
    'No breed-level published figure was found for this breed. The range is anchored to the published size-class figure and clinical convention, and the projection is deliberately widened to reflect that.',
} as const

export function Methodology({ projection }: { projection: Projection }) {
  const [open, setOpen] = useState(false)
  const { breed, factors } = projection

  const citations = [
    ...breed.evidence,
    ...projection.levers.flatMap((l) => l.citations),
    ...NEUTER_CITATIONS,
    ...(breed.species === 'dog' ? [NEUTER_AGE_CITATION] : []),
    ...STAGE_CITATIONS,
  ]
  const seen = new Set<string>()
  const unique = citations.filter((c) => {
    if (seen.has(c.label)) return false
    seen.add(c.label)
    return true
  })

  return (
    <section className="card overflow-hidden">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        className="flex w-full items-center justify-between gap-4 px-5 py-4 text-left sm:px-6"
      >
        <span>
          <span className="block font-display text-[20px] leading-tight text-ink">
            How we work this out
          </span>
          <span className="mt-0.5 block text-[13.5px] text-muted">
            The sources, the confidence level, and what moved the number.
          </span>
        </span>
        <span
          aria-hidden="true"
          className={`shrink-0 text-[20px] leading-none text-muted transition-transform ${open ? 'rotate-45' : ''}`}
        >
          +
        </span>
      </button>

      {open && (
        <div className="reveal space-y-6 border-t border-line px-5 py-6 sm:px-6">
          <div>
            <h3 className="label mb-2">Confidence in this breed's baseline</h3>
            <p className="text-[14.5px] leading-relaxed text-ink/85">
              <span
                className={`mr-2 inline-flex items-center rounded-full px-2.5 py-0.5 text-[12px] font-medium capitalize ${
                  breed.confidence === 'published'
                    ? 'bg-sage text-deep'
                    : breed.confidence === 'derived'
                      ? 'bg-cream text-muted'
                      : 'bg-accent/15 text-[#8A5510]'
                }`}
              >
                {breed.confidence}
              </span>
              {CONFIDENCE_COPY[breed.confidence]}
            </p>
            {breed.note && (
              <p className="mt-2.5 text-[14px] leading-relaxed text-muted">{breed.note}</p>
            )}
          </div>

          <div>
            <h3 className="label mb-2">What moved the projection</h3>
            {factors.length === 0 ? (
              <p className="text-[14.5px] text-muted">
                Nothing — everything is at the reference setting, so this is the breed baseline.
              </p>
            ) : (
              <ul className="space-y-2">
                {factors.map((f) => (
                  <li key={f.label} className="flex flex-wrap items-baseline gap-x-2.5 gap-y-1">
                    <span
                      className={`inline-flex w-[62px] justify-center rounded-full px-2 py-0.5 text-[12.5px] font-semibold ${
                        f.delta > 0 ? 'bg-sage text-deep' : 'bg-accent/15 text-[#8A5510]'
                      }`}
                    >
                      {f.delta > 0 ? '+' : ''}
                      {f.delta.toFixed(2)}
                    </span>
                    <span className="text-[14.5px] text-ink">{f.label}</span>
                    <span className="text-[13px] text-muted">
                      {EVIDENCE_LABELS[f.tier].label.toLowerCase()}
                    </span>
                  </li>
                ))}
              </ul>
            )}
            {projection.widened && (
              <p className="mt-3 text-[14px] leading-relaxed text-muted">
                The range is wider than usual here, because some of what we would want to know is
                either uncertain or missing. That widening is deliberate.
              </p>
            )}
          </div>

          <div>
            <h3 className="label mb-2">What we do not model</h3>
            <ul className="space-y-1.5 text-[14px] leading-relaxed text-muted">
              {breed.species === 'cat' && (
                <>
                  <li>
                    The road outside your door. We ask whether a cat goes out; we cannot ask what
                    they go out into, and a farm track and a main road are the same answer on this
                    form.
                  </li>
                  <li>
                    How much outdoor access is worth in years. The direction is documented and the
                    cost falls almost entirely on young cats — the size of the adjustment, and the
                    rate at which we taper it with age, are ours rather than a published figure.
                  </li>
                </>
              )}
              {breed.species === 'dog' && (
                <li>
                  Age at neutering, as a number of years. Where we ask for it — dogs whose adult
                  size puts them in the group Hart 2020 studied — it frames what to watch for on the
                  joint cards and nothing else. That study measured joint disorder incidence, not
                  survival, and turning one into the other would mean inventing a figure.
                </li>
              )}
              <li>Individual genetics. Everything here is a breed average.</li>
            </ul>
          </div>

          <div>
            <h3 className="label mb-2">Sources</h3>
            <ul className="space-y-2.5">
              {unique.map((c) => (
                <li key={c.label} className="text-[13.5px] leading-relaxed">
                  {c.url ? (
                    <a
                      href={c.url}
                      target="_blank"
                      rel="noreferrer"
                      className="text-forest underline underline-offset-4 hover:text-deep"
                    >
                      {c.label}
                    </a>
                  ) : (
                    <span className="text-ink">{c.label}</span>
                  )}
                  {c.metric && <span className="block text-muted">Measures: {c.metric}</span>}
                  {c.figure && <span className="block text-muted">Figure used: {c.figure}</span>}
                </li>
              ))}
            </ul>
            <p className="mt-4 text-[13.5px] leading-relaxed text-muted">
              Studies of pet longevity do not all measure the same thing. Life expectancy at age 0
              includes animals that die young and runs below median survival or median age at death.
              We never average figures across studies, and where no figure has been published for a
              breed we say so rather than filling the gap.
            </p>
          </div>
        </div>
      )}
    </section>
  )
}
