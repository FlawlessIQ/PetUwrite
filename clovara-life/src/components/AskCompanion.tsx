import { useState } from 'react'
import type { PetProfile, Projection } from '../data/types'
import { buildGroundingSet, composeRecall } from '../engine/grounding'
import { classify } from '../engine/safety'
import { asksForAVet, routeToVet } from '../engine/telehealth'
import { track } from '../analytics/track'
import type { CompanionBlock } from '../companion/blocks'
import { escalationBlocks, recallBlocks, vetBlocks } from '../companion/live'
import { AiReply, UserBubble } from './companion/Conversation'

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
 *
 * EVERY REPLY IS BLOCKS (DESIGN.md §5b, D-UI8). Recall, escalation and the
 * ask-for-a-vet route are restated as conversation-kit blocks by
 * `companion/live.ts` and rendered by the kit — each fact through the `fact`
 * block, with its source — so no path through the companion renders free text.
 */

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
  const [reply, setReply] = useState<{ asked: string; blocks: CompanionBlock[] } | null>(null)

  const ask = () => {
    const safety = classify(text, pet.species)
    if (safety.escalate) {
      setReply({ asked: text, blocks: escalationBlocks() })
      track('companion_asked', { escalated: true, pet_is_demo: !!pet.demo })
      return
    }

    // Asking for a vet is an ask, not a question about the record. Answering it
    // with facts about their pet would be a non-answer to somebody who has
    // decided they want a professional.
    if (asksForAVet(text)) {
      setReply({ asked: text, blocks: vetBlocks(routeToVet(pet.name), pet.name, pet.id) })
      track('companion_asked', { escalated: false, wants_vet: true, pet_is_demo: !!pet.demo })
      return
    }

    const set = buildGroundingSet(pet, projection, text, now)
    const r = composeRecall(pet, set, text)
    setReply({ asked: text, blocks: recallBlocks(r) })
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
        <h2 id="ask-heading" className="mt-1 font-display text-heading text-ink">
          It can only tell you what it already knows
        </h2>
        <p className="mt-1 text-body leading-relaxed text-ink-2">
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
            setReply(null)
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

        {reply && (
          <ol className="mt-5 flex flex-col gap-3.5" aria-live="polite" aria-label={`Answer about ${pet.name}`}>
            <UserBubble text={reply.asked} />
            <AiReply blocks={reply.blocks} ctx={{ petName: pet.name }} />
          </ol>
        )}
      </div>
    </section>
  )
}
