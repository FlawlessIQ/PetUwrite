/**
 * Gemini-backed parsing (SPEC §4.3), server-side only.
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * THE KEY NEVER REACHES A BROWSER. It lives in Secret Manager as
 * LIFE_GEMINI_API_KEY and is read by the function runtime — separate from the
 * underwriting app's GEMINI_API_KEY so neither app's rotation breaks the other.
 *
 * THE MODEL RETURNS CANDIDATES, NEVER DATA (invariant 8). Everything it
 * produces goes in front of the owner as confirm-chips before it touches a
 * record. The response schema below cannot express a stored field — it has no
 * provenance, no confirmedAt, and the client has no path that writes one
 * without `confirm()`.
 *
 * THE PROMPT IS BUILT TO UNDER-REPORT. A model asked to extract facts from
 * "no history of seizures" will happily return a seizure history, and a
 * confirmed hallucination is indistinguishable from a real record forever
 * after. So: only what was positively stated, negations are not facts, and
 * when in doubt return nothing.
 * ═══════════════════════════════════════════════════════════════════════════
 */
const { HttpsError } = require('firebase-functions/v2/https')

/**
 * Pinned, not `-latest`.
 *
 * Chosen empirically rather than by reputation: `gemini-2.5-flash` 404s on this
 * endpoint, and the aliases move under you. This one was tested on the case
 * that matters — "no history of seizures", "the vet ruled out hip dysplasia",
 * "he does not have diabetes" all correctly returned nothing, while a positive
 * sentence gave weight and neuter status. A model swap must repeat that test.
 */
const MODEL = 'gemini-3.5-flash'
const ENDPOINT = (key) =>
  `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${encodeURIComponent(key)}`

/** What the model is allowed to return. It cannot express a stored field. */
const SCHEMA = {
  type: 'object',
  properties: {
    candidates: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          kind: { type: 'string', enum: ['weight', 'condition', 'vaccine', 'visit'] },
          label: { type: 'string' },
          sourceText: { type: 'string' },
          weightLb: { type: 'number' },
          neutered: { type: 'boolean' },
          conditionName: { type: 'string' },
        },
        required: ['kind', 'label', 'sourceText'],
      },
    },
  },
  required: ['candidates'],
}

const SYSTEM = `You read one sentence an owner wrote about their pet and list only what they positively stated.

RULES, IN ORDER OF IMPORTANCE:
1. A negation is not a fact. "No history of seizures", "never had arthritis", "the vet ruled out hip dysplasia" — these state the ABSENCE of something. Return nothing for them. This is the most common way to be wrong and it is the most damaging.
2. Only what is stated. Do not infer a condition from a symptom, an age from a stage, or a weight from a breed.
3. sourceText must be the owner's own words, copied exactly, not your paraphrase. If you cannot quote it, do not report it.
4. When unsure, return nothing. An empty list is a good answer.
5. Never diagnose. If they describe a symptom, that is not a condition.

Convert kilograms to pounds for weightLb. Return JSON only.`

async function parseWithGemini(text, apiKey) {
  const said = String(text || '').trim()
  if (!said) return { candidates: [], providerId: 'gemini' }
  if (said.length > 2000) throw new HttpsError('invalid-argument', 'That is longer than we can read.')
  if (!apiKey) throw new HttpsError('failed-precondition', 'No model key configured.')

  const res = await fetch(ENDPOINT(apiKey), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: SYSTEM }] },
      contents: [{ role: 'user', parts: [{ text: said }] }],
      generationConfig: {
        // Deterministic: the same sentence must produce the same chips, or an
        // owner who retypes something gets a different set to confirm.
        temperature: 0,
        responseMimeType: 'application/json',
        responseSchema: SCHEMA,
      },
    }),
  })
  if (!res.ok) {
    throw new HttpsError('unavailable', `The model did not answer (${res.status}).`)
  }
  const body = await res.json()
  const raw = body?.candidates?.[0]?.content?.parts?.[0]?.text
  let parsed
  try {
    parsed = JSON.parse(raw || '{}')
  } catch {
    return { candidates: [], providerId: 'gemini' }
  }

  return { candidates: toCandidates(parsed.candidates, said), providerId: 'gemini' }
}

/**
 * Turns the model's output into Candidates, dropping anything it cannot
 * substantiate.
 *
 * The sourceText check is the load-bearing one: if the quoted words are not
 * actually in what the owner wrote, the model made them up, and the candidate
 * goes in the bin rather than in front of a person.
 */
function toCandidates(list, said) {
  const lower = said.toLowerCase()
  const out = []
  for (const [i, c] of (Array.isArray(list) ? list : []).entries()) {
    if (!c || typeof c.label !== 'string' || typeof c.sourceText !== 'string') continue
    if (!c.sourceText.trim() || !lower.includes(c.sourceText.trim().toLowerCase())) continue

    let value = null
    if (c.kind === 'weight' && Number.isFinite(c.weightLb) && c.weightLb > 0 && c.weightLb < 400) {
      value = { weightLb: Math.round(c.weightLb * 10) / 10 }
    } else if (c.kind === 'condition' && typeof c.neutered === 'boolean') {
      value = { neutered: c.neutered }
    } else if (c.kind === 'condition' && typeof c.conditionName === 'string' && c.conditionName) {
      value = { conditionName: c.conditionName }
    }
    if (!value) continue

    out.push({
      id: `g${i}`,
      kind: c.kind,
      label: c.label.slice(0, 120),
      sourceText: c.sourceText.slice(0, 200),
      confidence: 0.6,
      value,
    })
  }
  return out
}

module.exports = { parseWithGemini, toCandidates, SYSTEM, MODEL }
