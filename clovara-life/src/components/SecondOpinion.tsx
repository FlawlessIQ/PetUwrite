import { useState } from 'react'
import type { PetProfile, Projection } from '../data/types'
import { questionsFor } from '../engine/secondOpinion'
import { NOT_A_VERDICT, OPENING, PRICE_NOTE } from '../data/secondOpinion'
import { track } from '../analytics/track'

/**
 * Second opinion (SPEC-HORIZON §1.3).
 *
 * Questions to ask the vet who made the recommendation — never an alternative
 * view. Nothing is stored and nothing is sent anywhere: the text stays in the
 * component, which is why it needs no security review and no model.
 */
export function SecondOpinion({
  pet,
  projection,
}: {
  pet: PetProfile
  projection: Projection
}) {
  const [text, setText] = useState('')
  const [result, setResult] = useState<ReturnType<typeof questionsFor> | null>(null)

  const go = () => {
    const r = questionsFor(text, pet, projection)
    setResult(r)
    track('second_opinion', { questions: r.questions.length, pet_is_demo: !!pet.demo })
  }

  return (
    <section className="card overflow-hidden" aria-labelledby="opinion-heading">
      <div className="border-b border-line bg-cream/50 px-5 py-4">
        <p className="label">Before you agree to it</p>
        <h2 id="opinion-heading" className="mt-1 font-display text-[20px] text-ink">
          What to ask your vet
        </h2>
        <p className="mt-1 text-[13.5px] leading-relaxed text-ink-2">{OPENING}</p>
      </div>

      <div className="px-5 py-5">
        <label htmlFor="opinion" className="sr-only">
          What were you told about {pet.name}?
        </label>
        <textarea
          id="opinion"
          rows={3}
          className="field resize-none"
          placeholder="They have recommended surgery on her cruciate, about £4,800…"
          value={text}
          onChange={(e) => {
            setText(e.target.value)
            setResult(null)
          }}
        />
        <button type="button" className="pill-primary mt-3 w-full" onClick={go}>
          What should I ask?
        </button>

        {result && (
          <div className="mt-5">
            <p className="rounded-soft bg-sage/50 px-4 py-3 text-[13.5px] leading-relaxed text-deep">
              {NOT_A_VERDICT}
            </p>

            <ol className="mt-4 space-y-3.5">
              {result.questions.map((q, i) => (
                <li key={q.id} className="flex gap-3">
                  <span aria-hidden="true" className="shrink-0 text-[14px] font-medium text-forest">
                    {i + 1}.
                  </span>
                  <span>
                    <span className="block text-[15px] leading-snug text-ink">{q.text}</span>
                    <span className="mt-0.5 block text-[13px] leading-relaxed text-ink-2">
                      {q.because}
                    </span>
                  </span>
                </li>
              ))}
            </ol>

            {result.fromTheRecord.length > 0 && (
              <div className="mt-5">
                <p className="label">Worth mentioning, from {pet.name}&rsquo;s record</p>
                <ul className="mt-2 space-y-1.5">
                  {result.fromTheRecord.map((r) => (
                    <li key={r} className="text-[13.5px] leading-relaxed text-ink">
                      {r}
                    </li>
                  ))}
                </ul>
              </div>
            )}

            <p className="mt-5 text-[12.5px] leading-relaxed text-ink-2">{PRICE_NOTE}</p>
          </div>
        )}
      </div>
    </section>
  )
}
