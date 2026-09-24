/**
 * C3 — model composition (SPEC-COMPANION §3.3), server-side.
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * SHIPS OFF. `COMPANION_MODEL_ENABLED` is false and stays false until Conor
 * makes the privacy decision in SPEC-COMPANION §10: turning this on sends text
 * an owner wrote about their pet to Google. That is a processor question and a
 * Data Covenant question, not an engineering one.
 *
 * THE MODEL ADDS LANGUAGE, NOT INFORMATION. It receives the grounding set and
 * may use nothing else. The response schema cannot express an uncited sentence,
 * and the verification that runs afterwards drops any sentence citing a fact id
 * that is not in the set — so an invented citation is caught even though the
 * schema permits the shape.
 *
 * TEMPERATURE 0, PINNED MODEL. The same question must produce the same answer:
 * an owner who rephrases and gets a different account of their pet's record has
 * been told that one of the two was invented.
 * ═══════════════════════════════════════════════════════════════════════════
 */
const { HttpsError } = require('firebase-functions/v2/https')

/** Conor's call, SPEC-COMPANION §10. */
const COMPANION_MODEL_ENABLED = false

const MODEL = 'gemini-3.5-flash'
const ENDPOINT = (key) =>
  `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${encodeURIComponent(key)}`

/** The shape cannot express a sentence without citations. */
const SCHEMA = {
  type: 'object',
  properties: {
    sentences: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          text: { type: 'string' },
          citesFactIds: { type: 'array', items: { type: 'string' } },
        },
        required: ['text', 'citesFactIds'],
      },
    },
    routeTo: { type: 'string', enum: ['vet-soon', 'vet-now', 'none'] },
    iDoNotKnow: { type: 'boolean' },
  },
  required: ['sentences'],
}

const SYSTEM = `You put an owner's own records into plain sentences. You are not a vet and you never act like one.

YOU MAY ONLY USE THE FACTS GIVEN. Each fact has an id. Every sentence must cite the ids it came from. If a sentence is not supported by a fact, do not write it — there is no credit for length.

NEVER:
- say what something is, might be, or sounds like. Not "probably", not "could be", not "consistent with". If asked what it is, say you cannot tell them and that it needs a vet who can examine the animal.
- give a dose, a drug, or a home treatment, or suggest making an animal vomit.
- promise a longer life, more years, or added time.
- invent a fact id. If nothing fits, set iDoNotKnow true and return no sentences.

ALWAYS:
- write as though speaking to the owner, plainly, without jargon.
- set routeTo "vet-now" if the facts describe something urgent, "vet-soon" if the record has something relevant to what they asked, otherwise "none".
- prefer saying less. An honest short answer beats a complete-sounding one.`

async function composeReply({ utterance, facts, petName }, apiKey) {
  if (!COMPANION_MODEL_ENABLED) {
    throw new HttpsError(
      'failed-precondition',
      'Model composition is switched off pending a decision about sending owner text to a third party.',
    )
  }
  if (!apiKey) throw new HttpsError('failed-precondition', 'No model key configured.')
  const said = String(utterance || '').trim()
  if (!said) return { sentences: [], iDoNotKnow: true }
  if (said.length > 2000) throw new HttpsError('invalid-argument', 'That is longer than we can read.')

  const factBlock = (facts || [])
    .map((f) => `${f.id}: ${f.claim}`)
    .join('\n')

  const res = await fetch(ENDPOINT(apiKey), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: SYSTEM }] },
      contents: [
        {
          role: 'user',
          parts: [
            {
              text: `Pet: ${petName}\n\nFACTS YOU MAY USE:\n${factBlock || '(none)'}\n\nTHE OWNER ASKED:\n${said}`,
            },
          ],
        },
      ],
      generationConfig: {
        temperature: 0,
        responseMimeType: 'application/json',
        responseSchema: SCHEMA,
      },
    }),
  })
  if (!res.ok) throw new HttpsError('unavailable', `The model did not answer (${res.status}).`)

  const body = await res.json()
  const raw = body?.candidates?.[0]?.content?.parts?.[0]?.text
  try {
    const parsed = JSON.parse(raw || '{}')
    return {
      sentences: Array.isArray(parsed.sentences) ? parsed.sentences : [],
      routeTo: parsed.routeTo,
      iDoNotKnow: !!parsed.iDoNotKnow,
    }
  } catch {
    return { sentences: [], iDoNotKnow: true }
  }
}

module.exports = { composeReply, COMPANION_MODEL_ENABLED, SYSTEM, SCHEMA, MODEL }
