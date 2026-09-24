/**
 * Second opinion (SPEC-HORIZON §1.3) — the questions worth asking.
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * WHAT THIS IS NOT, AND THE LINE IT WILL NOT CROSS.
 *
 * It never second-guesses a clinical decision. "You may not need this", about a
 * procedure a vet has recommended, from a product that has not examined the
 * animal, is the most harmful thing this feature could do. The output is
 * QUESTIONS TO ASK THE VET WHO RECOMMENDED IT — never an alternative view, a
 * likelihood, or a suggestion that the recommendation is wrong.
 *
 * Every question below passes one test: a good vet would be pleased to be asked
 * it. A question designed to catch somebody out is not on this list.
 *
 * TWO DELIBERATE OMISSIONS:
 *
 *  1. NO COST RANGE. SPEC-HORIZON §1.3 left it open and recommended shipping
 *     without one; that recommendation stands. The plausible data source is our
 *     own claims, which is close to a Data Covenant line, and a range implies a
 *     verdict — a practice at the top of it may be the better practice.
 *
 *  2. NO DOCUMENT UPLOAD. The spec assumed extraction over an estimate, which
 *     sits behind the Firestore security review. Typing what you were told
 *     needs no storage and no review, and the questions are the value. Upload
 *     can arrive later through the extraction pipeline that already exists.
 * ═══════════════════════════════════════════════════════════════════════════
 */

export interface Question {
  id: string
  text: string
  /** Why it is worth asking, for the owner rather than for the vet. */
  because: string
  /** Lowercase triggers. Empty means always. */
  when?: string[]
}

export const QUESTIONS: Question[] = [
  // ── Always ──────────────────────────────────────────────────────────────
  {
    id: 'do-nothing',
    text: 'What happens if we do nothing, or wait?',
    because:
      'Every recommendation has a comparison, and it is rarely written down. Sometimes waiting is reasonable and sometimes it is how a small problem becomes a large one — either answer is useful.',
  },
  {
    id: 'alternatives',
    text: 'Is there anything else we could try first?',
    because: 'There is often a less invasive option, and often there is not. Asking costs nothing.',
  },
  {
    id: 'urgency',
    text: 'Does this need doing now, or could it wait a few weeks?',
    because:
      'It changes whether you are arranging time off and money this month or next, and it is the question people most often forget in the room.',
  },
  {
    id: 'recovery',
    text: 'What does recovery actually look like, day to day?',
    because:
      'Crate rest, lifting, stairs, time off work. This is the part that surprises people and the part that decides whether it goes well.',
  },
  {
    id: 'included',
    text: 'What is included in that price — follow-ups, medication, complications?',
    because:
      'Not a challenge to the figure. Estimates are quoted differently between practices and knowing the boundary prevents a second bill you were not expecting.',
  },
  {
    id: 'who',
    text: 'Will you be doing it, or would you refer to somebody who does more of them?',
    because:
      'A good vet is not offended by this. For some procedures volume matters, and they will know who does more.',
  },
  {
    id: 'risks',
    text: 'What are the risks, and how often do they happen here?',
    because: 'General risk is in a leaflet. What happens in that practice is not.',
  },
  {
    id: 'success',
    text: 'What does a good outcome look like, and how likely is it for a pet like mine?',
    because:
      'Age, weight and other conditions all change the answer, and the honest version is a range rather than a promise.',
  },

  // ── Triggered ───────────────────────────────────────────────────────────
  {
    id: 'anaesthetic',
    text: 'What are the anaesthetic risks at their age, and what checks happen first?',
    when: ['anaesthetic', 'anesthetic', 'surgery', 'operation', 'operate', 'general', 'sedation', 'sedated'],
    because: 'Pre-anaesthetic bloods and a plan for an older animal are routine, and worth confirming.',
  },
  {
    id: 'pain',
    text: 'What is the plan for pain afterwards, and for how long?',
    when: ['surgery', 'operation', 'operate', 'extraction', 'amputation', 'repair'],
    because: 'Pain relief plans differ, and running out on a Sunday is a common and avoidable problem.',
  },
  {
    id: 'insurance-preauth',
    text: 'Can you pre-authorise this with my insurer before we book?',
    when: ['insurance', 'insured', 'claim', 'covered', 'policy'],
    because:
      'Pre-authorisation turns a hope into a written answer, and most practices will do it if asked.',
  },
  {
    id: 'second-opinion-referral',
    text: 'Would you mind if I got a second opinion?',
    when: ['second opinion', 'not sure', 'unsure', 'worried', 'big decision', 'expensive'],
    because:
      'Asking this openly is normal and most vets will help arrange it. Going behind their back makes the next conversation harder.',
  },
  {
    id: 'age',
    text: 'Given their age, does that change what you would recommend?',
    when: ['old', 'older', 'elderly', 'senior', 'ancient'],
    because: 'It often does, in both directions, and it is better said out loud.',
  },
]

export const OPENING =
  'Tell us what you were told — the procedure, the number, whatever you can remember. Nothing is stored and nothing is sent anywhere.'

/**
 * The line the whole surface turns on.
 */
export const NOT_A_VERDICT =
  'These are questions, not doubts. We have not examined your pet, we do not know what your vet knows, and nothing here suggests the recommendation is wrong — only that it is yours to understand before you agree to it.'

export const PRICE_NOTE =
  'We deliberately do not tell you whether the price is fair. We have no reliable way to know, and a practice at the top of a range may be the better practice. Asking what is included is more useful than comparing totals.'
