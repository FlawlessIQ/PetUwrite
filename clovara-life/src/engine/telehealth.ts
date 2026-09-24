/**
 * C4 — routing somebody to a vet (SPEC-COMPANION §6).
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * WHAT THIS DELIBERATELY IS NOT: a `TelehealthProvider` interface.
 *
 * The other four seams in this codebase — rating, fitness, extraction, places —
 * were each built against a shape that was actually known: a real API, a
 * specified interface, or an obvious domain. There is no telehealth partner and
 * no candidate, so an interface invented now would be a guess at somebody
 * else's API, and the first real integration would delete it. Building it would
 * look like progress and produce work for whoever does the real thing.
 *
 * WHAT IS REAL AND BUILDABLE TODAY: the ask. Somebody typing "can I speak to a
 * vet" currently gets facts about their pet's record, which is not an answer.
 * They should get the truth — we have no vet to put them through to — plus the
 * two things that actually help: their summary, and how to reach somebody now.
 *
 * When a partner lands, `available` becomes true and this file grows an
 * integration. The surfaces do not change.
 * ═══════════════════════════════════════════════════════════════════════════
 *
 * Pure.
 */

/** No partner. ROADMAP carries this as unscoped. */
export const TELEHEALTH_AVAILABLE = false

const ASKS = [
  'speak to a vet', 'talk to a vet', 'see a vet', 'book a vet', 'book an appointment',
  'video vet', 'video call', 'telehealth', 'tele vet', 'online vet', 'vet online',
  'get a vet', 'get me a vet', 'need a vet', 'find a vet', 'find me a vet', 'need to see a vet', 'call a vet', 'ring a vet', 'vet appointment',
  'phone a vet', 'consult', 'second opinion',
]

/** Is this somebody asking to be put in front of a vet? */
export function asksForAVet(utterance: string): boolean {
  const said = utterance
    .toLowerCase()
    .replace(/[’']/g, "'")
    .replace(/[^a-z0-9' ]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
  return ASKS.some((a) => said.includes(a))
}

export interface VetRouting {
  /** True once a partner exists. */
  available: boolean
  headline: string
  body: string
  /** What we can actually do, in the order it helps. */
  steps: string[]
}

/**
 * What to say when somebody asks for a vet.
 *
 * The honest version. It does not apologise at length, it does not promise the
 * feature is coming, and it leads with the thing that helps most — the summary
 * that is already built, which is the whole reason a consultation goes better.
 */
export function routeToVet(petName: string): VetRouting {
  if (TELEHEALTH_AVAILABLE) {
    // A partner would be reached here. Nothing above this line changes.
    return {
      available: true,
      headline: `Booking a video vet for ${petName}`,
      body: '',
      steps: [],
    }
  }

  return {
    available: false,
    headline: 'We cannot put you through to a vet ourselves',
    body: `There is no video vet behind Clovara yet, and pretending otherwise would waste the time of somebody who needs one. What we can do is make the appointment you book go better.`,
    steps: [
      `Copy ${petName}'s summary — everything on their record, in one page a vet can read in thirty seconds.`,
      'Ring your own practice. Out of hours, their number will tell you who covers them.',
      'If it cannot wait, search for an emergency vet near you, or ring a poison line — they will tell you where to go.',
    ],
  }
}
