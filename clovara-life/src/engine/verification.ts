/**
 * C3 — verification over a composed reply (SPEC-COMPANION §3.4).
 *
 * Pure. Runs after every model call, before a word reaches a person.
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * THE JOB: assume the model misbehaved, and find out how.
 *
 * Not "check the model did well". The failure mode of a grounded assistant is a
 * fluent paragraph in which three sentences are sourced and the fourth is
 * invented — and the fourth is the one an owner acts on. So every sentence is
 * guilty until it cites a fact that actually exists in the set the retrieval
 * produced.
 *
 * FOUR GATES, IN ORDER:
 *  1. Citation — a sentence citing nothing, or citing a fact id that is not in
 *     the grounding set, is dropped. A model that invents an id has invented
 *     the sentence too.
 *  2. Language — diagnosis, speculation, dosing, and longer-life claims are
 *     dropped whatever they cite, because a true citation does not make
 *     "it is probably arthritis" safe to say.
 *  3. Proportion — if too much was dropped, the whole reply is discarded. A
 *     paragraph with its middle removed reads as though we are hiding
 *     something, and it is evidence the model was not doing what was asked.
 *  4. Emptiness — nothing left means we say we do not know, which is always an
 *     available answer (invariant 9).
 * ═══════════════════════════════════════════════════════════════════════════
 */
import type { GroundedFact } from './grounding'

export interface ComposedSentence {
  text: string
  citesFactIds: string[]
}

export interface ComposedReply {
  sentences: ComposedSentence[]
  /**
   * 'telehealth' is deliberately absent. SPEC-COMPANION §6 lists it as a
   * destination, and there is no partner — so nothing may produce a route we
   * cannot honour. Asking for a vet is handled by `telehealth.ts`, which tells
   * the truth instead. The value returns here when a partner does.
   */
  routeTo?: 'vet-soon' | 'vet-now' | 'none'
  iDoNotKnow?: boolean
}

export type DropReason = 'uncited' | 'unknown-fact' | 'diagnostic' | 'dosing' | 'longer-life'

export interface VerifiedReply {
  /** What may be shown. */
  sentences: ComposedSentence[]
  dropped: { text: string; reason: DropReason }[]
  /** True when the whole reply was thrown away rather than shown in pieces. */
  discarded: boolean
  route: 'vet-soon' | 'vet-now' | 'none'
  /** Shown instead, when nothing survived. */
  fallback: string | null
}

/**
 * Discard the whole reply when more than this share of it fails.
 *
 * SPEC-COMPANION §10 leaves the number to Conor. A third is the working
 * default: below it, a dropped sentence reads as an edit; above it, the
 * remainder is a paragraph with holes in it, and the holes are where the model
 * was doing something we did not ask for.
 */
export const DISCARD_THRESHOLD = 1 / 3

/** Never sayable, however well cited. */
const BANNED: { reason: DropReason; pattern: RegExp }[] = [
  {
    reason: 'diagnostic',
    pattern:
      /\b(sounds like|looks like|probably|most likely|likely to be|it could be|it may be|I think it|my guess|appears to be|consistent with|indicative of|suggests that|diagnos|differential|rule out|it is (?:almost certainly|certainly|clearly))\b/i,
  },
  {
    reason: 'dosing',
    pattern:
      /\b(\d+\s*(?:mg|ml|mcg)|give (?:him|her|them)|you can give|safe to give|administer|dose of|twice daily|BID\b|SID\b|induce vomiting|make (?:him|her) (?:sick|vomit)|hydrogen peroxide)\b/i,
  },
  {
    reason: 'longer-life',
    pattern: /\b(live longer|longer life|extra years|add years|more years together)\b/i,
  },
]

export function verify(
  reply: ComposedReply,
  facts: GroundedFact[],
  petName: string,
): VerifiedReply {
  const known = new Set(facts.map((f) => f.id))
  const kept: ComposedSentence[] = []
  const dropped: { text: string; reason: DropReason }[] = []

  for (const s of reply.sentences ?? []) {
    const text = (s?.text ?? '').trim()
    if (!text) continue

    const cites = Array.isArray(s.citesFactIds) ? s.citesFactIds : []
    if (cites.length === 0) {
      dropped.push({ text, reason: 'uncited' })
      continue
    }
    // A model that invents a fact id has invented the sentence with it.
    if (!cites.every((id) => known.has(id))) {
      dropped.push({ text, reason: 'unknown-fact' })
      continue
    }
    const banned = BANNED.find((b) => b.pattern.test(text))
    if (banned) {
      dropped.push({ text, reason: banned.reason })
      continue
    }
    kept.push({ text, citesFactIds: cites })
  }

  const total = kept.length + dropped.length
  const discarded = total > 0 && dropped.length / total > DISCARD_THRESHOLD

  // Routing survives a discard. If the model thought this needed a vet, that
  // judgement is not the part we distrust — the prose is.
  const route =
    reply.routeTo === 'vet-now' ? 'vet-now' : reply.routeTo === 'vet-soon' ? 'vet-soon' : 'none'

  if (discarded || kept.length === 0) {
    return {
      sentences: [],
      dropped,
      discarded,
      route,
      fallback: `We could not put together an answer we are confident enough to show you about ${petName}. That is our problem rather than yours — everything we hold is on their record, and if something is worrying you it is worth a call to your vet.`,
    }
  }

  return { sentences: kept, dropped, discarded: false, route, fallback: null }
}
