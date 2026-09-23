/**
 * "Tell me about him" (SPEC §4.3) — conversational onboarding, behind a flag.
 *
 * SPEC marks this P1-OPTIONAL and says exactly how to build it: "build it as an
 * alternate entry to the same capture functions, not a fork". So this produces
 * the same `Candidate` list the vet-record extractor produces, goes through the
 * same confirm-chips, and lands in the same fields. There is no second parser
 * and no second way into the record.
 *
 * It ships off: it needs an LLM key, and the deterministic parser below is a
 * fallback rather than the feature. The fallback exists because a flag that
 * turns on nothing is untestable, and because the handful of things it CAN
 * pull out without a model are the ones people actually type first.
 */
import type { Candidate } from './provider'

/** Needs an LLM key. The deterministic parser below is a floor, not the feature. */
export const CONVERSATIONAL_ONBOARDING_ENABLED = false

const WEIGHT = /\b(\d{1,3}(?:\.\d)?)\s*(kg|kilos?|kilograms?|lb|lbs|pounds?)\b/i
const NEUTER = /\b(neutered|spayed|castrated|fixed|done)\b/i
const NOT_NEUTER = /\b(not (neutered|spayed|fixed|done)|entire|intact|un-?neutered|un-?spayed)\b/i

/**
 * What can be pulled out of a sentence with no model at all.
 *
 * DELIBERATELY CONSERVATIVE. It reads weight and neuter status and nothing
 * else. A regex that guessed at conditions from free text would produce
 * confident nonsense — "no history of seizures" contains "seizures" — and
 * every candidate here goes in front of an owner as something we think we
 * heard. Producing fewer, righter candidates is the whole job.
 */
export function parseUtterance(text: string, now: Date): Candidate[] {
  const out: Candidate[] = []
  const said = text.trim()
  if (!said) return out

  const w = WEIGHT.exec(said)
  if (w) {
    const n = Number(w[1])
    const unit = w[2].toLowerCase()
    const lb = unit.startsWith('k') ? Math.round(n * 2.20462 * 10) / 10 : n
    if (Number.isFinite(lb) && lb > 0 && lb < 400) {
      out.push({
        id: `weight-${now.getTime()}`,
        kind: 'weight',
        label: `Weighs about ${lb} lb`,
        sourceText: w[0],
        confidence: 0.75,
        value: { weightLb: lb },
      })
    }
  }

  // Order matters: "not neutered" contains "neutered".
  if (NOT_NEUTER.test(said)) {
    out.push({
      id: `neuter-${now.getTime()}`,
      kind: 'condition',
      label: 'Not neutered or spayed',
      sourceText: NOT_NEUTER.exec(said)![0],
      confidence: 0.7,
      value: { neutered: false },
    })
  } else if (NEUTER.test(said)) {
    out.push({
      id: `neuter-${now.getTime()}`,
      kind: 'condition',
      label: 'Neutered or spayed',
      sourceText: NEUTER.exec(said)![0],
      confidence: 0.7,
      value: { neutered: true },
    })
  }

  return out
}

export const CONVERSATIONAL_PROMPT = 'Tell me about them, in your own words.'

export const CONVERSATIONAL_DISCLOSURE =
  'Whatever you write, we will show you what we think we heard before anything is saved. Nothing goes on their record until you say it is right.'
