import { useState } from 'react'
import type { PetProfile, Projection } from '../data/types'
import { buildGroundingSet, composeRecall, type Recall } from '../engine/grounding'
import { classify } from '../engine/safety'
import { RED_FLAG_BODY, RED_FLAG_HEADLINE } from '../data/redFlags'
import { track } from '../analytics/track'

/**
 * C2 — the grounded companion (SPEC-COMPANION §3.2, §9).
 *
 * No model. Somebody asks; retrieval finds what is already on the record; the
 * reply is assembled from those facts and nothing else. Every line shows where
 * it came from.
 *
 * THE SAFETY CLASSIFIER RUNS FIRST, always, exactly as it does on its own
 * surface. A grounded recall about hip dysplasia is the wrong answer to
 * "he has collapsed", and the ordering is what makes sure it is never given.
 *
 * WHEN IT KNOWS NOTHING IT SAYS SO (invariant 9). That path is deliberately not
 * softened — "we hold eleven things about Max and none of them speak to this"
 * is more useful than a sentence that sounds like an answer.
 */
const SOURCE_LABEL: Record<string, string> = {
  'pet-record': 'from what you told us',
  'breed-table': 'from the breed research',
  projection: 'from the plan',
  vaccination: 'from your vaccination notes',
  'care-note': 'from your notes',
}

export function AskCompanion({
  pet,
  projection,
  now = new Date(),
}: {
  pet: PetProfile
  projection: Projection
  now?: Date
}) {
  const [text, setText] = useState('')
  const [recall, setRecall] = useState<Recall | null>(null)
  const [escalate, setEscalate] = useState<ReturnType<typeof classify> | null>(null)

  const ask = () => {
    const safety = classify(text, pet.species)
    if (safety.escalate) {
      setEscalate(safety)
      setRecall(null)
      track('companion_asked', { escalated: true, pet_is_demo: !!pet.demo })
      return
    }
    setEscalate(null)
    const set = buildGroundingSet(pet, projection, text, now)
    const r = composeRecall(pet, set, text)
    setRecall(r)
    track('companion_asked', {
      escalated: false,
      facts: r.facts.length,
      knew_nothing: r.opening === null,
      pet_is_demo: !!pet.demo,
    })
  }

  return (
    <section className="card overflow-hidden" aria-labelledby="ask-heading">
      <div className="border-b border-line bg-cream/50 px-5 py-4">
        <p className="label">Ask about {pet.name}</p>
        <h2 id="ask-heading" className="mt-1 font-display text-[20px] text-ink">
          It can only tell you what it already knows
        </h2>
        <p className="mt-1 text-[13.5px] leading-relaxed text-muted">
          Everything it says comes from {pet.name}&rsquo;s record or the breed research, and it
          shows you which. It does not guess, and it cannot examine {pet.name}.
        </p>
      </div>

      <div className="px-5 py-5">
        <label htmlFor="ask" className="sr-only">
          What would you like to know about {pet.name}?
        </label>
        <textarea
          id="ask"
          rows={3}
          className="field resize-none"
          placeholder={`Has ${pet.name} been slowing down on walks?`}
          value={text}
          onChange={(e) => {
            setText(e.target.value)
            setRecall(null)
            setEscalate(null)
          }}
        />
        <button
          type="button"
          className="pill-primary mt-3 w-full"
          onClick={ask}
          disabled={!text.trim()}
        >
          Ask
        </button>

        {escalate && (
          <div className="mt-5 rounded-soft border border-[#B3261E]/30 bg-[#B3261E]/[0.06] px-4 py-4">
            <p className="font-display text-[19px] leading-tight text-[#8C1D18]">
              {RED_FLAG_HEADLINE}
            </p>
            <p className="mt-2 text-[14px] leading-relaxed text-[#8C1D18]">{RED_FLAG_BODY}</p>
            <a
              href="#/wrong"
              className="mt-3 inline-block text-action text-[14px] font-medium text-[#8C1D18]"
            >
              What to do now
            </a>
          </div>
        )}

        {recall && (
          <div className="mt-5">
            {recall.opening && (
              <p className="text-[15px] leading-relaxed text-ink">{recall.opening}</p>
            )}

            {recall.facts.length > 0 && (
              <ul className="mt-3 space-y-2.5">
                {recall.facts.map((f) => (
                  <li key={f.id} className="rounded-soft border border-line bg-white px-4 py-3">
                    <p className="text-[14.5px] leading-relaxed text-ink">{f.claim}</p>
                    <p className="mt-1 text-[12.5px] text-muted">
                      {SOURCE_LABEL[f.source.kind] ?? f.source.kind}
                      {f.source.kind === 'breed-table' && ` · ${f.source.citation} evidence`}
                    </p>
                  </li>
                ))}
              </ul>
            )}

            <p
              className={`mt-3 text-[13.5px] leading-relaxed ${
                recall.route === 'vet-soon' ? 'text-deep' : 'text-muted'
              }`}
            >
              {recall.closing}
            </p>
          </div>
        )}
      </div>
    </section>
  )
}
