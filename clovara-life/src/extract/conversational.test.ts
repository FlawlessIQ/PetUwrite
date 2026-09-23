import { describe, expect, it } from 'vitest'
import {
  CONVERSATIONAL_ONBOARDING_ENABLED,
  CONVERSATIONAL_DISCLOSURE,
  parseUtterance,
} from './conversational'

const NOW = new Date('2026-09-23T12:00:00Z')
const parse = (s: string) => parseUtterance(s, NOW)

describe('the flag', () => {
  it('is off — it needs an LLM key', () => {
    expect(CONVERSATIONAL_ONBOARDING_ENABLED).toBe(false)
  })

  it('promises confirmation before anything is saved (invariant 8)', () => {
    expect(CONVERSATIONAL_DISCLOSURE).toMatch(/what we think we heard/i)
    expect(CONVERSATIONAL_DISCLOSURE).toMatch(/until you say it is right/i)
  })
})

describe('what the fallback parser reads', () => {
  it('reads pounds', () => {
    const [c] = parse('He is about 68 lbs and full of beans')
    expect(c.kind).toBe('weight')
    expect(c.value).toEqual({ weightLb: 68 })
  })

  it('converts kilos', () => {
    const [c] = parse('She weighs 30kg')
    expect((c.value as { weightLb: number }).weightLb).toBeCloseTo(66.1, 1)
  })

  it('reads neutered', () => {
    expect(parse('He is neutered').find((c) => c.label.includes('Neutered'))?.value).toEqual({
      neutered: true,
    })
  })

  it('reads NOT neutered, and does not get it backwards', () => {
    // The load-bearing case: "not neutered" contains "neutered", and getting
    // this the wrong way round would put a false fact in front of an owner
    // with our confidence behind it.
    for (const said of ['He is not neutered', 'She is intact', 'not spayed yet', 'he is entire']) {
      const c = parse(said)[0]
      expect(c?.value, said).toEqual({ neutered: false })
    }
  })

  it('reads both from one sentence', () => {
    const cs = parse('Scout is 30kg and neutered')
    expect(cs).toHaveLength(2)
    expect(cs.map((c) => c.kind).sort()).toEqual(['condition', 'weight'])
  })

  it('keeps the words it read, so an owner can check them', () => {
    const [c] = parse('He is about 68 lbs')
    expect(c.sourceText).toMatch(/68 lbs/)
  })

  it('refuses nonsense weights rather than confirming them', () => {
    expect(parse('he is 900 lbs')).toHaveLength(0)
    expect(parse('she is 0 kg')).toHaveLength(0)
  })

  it('NEVER guesses at conditions from free text', () => {
    // "No history of seizures" contains "seizures". A regex that guessed would
    // produce confident nonsense, and every candidate goes in front of an owner
    // as something we think we heard.
    for (const said of [
      'no history of seizures',
      'never had arthritis',
      'the vet ruled out hip dysplasia',
      'he does not have diabetes',
    ]) {
      const kinds = parse(said).map((c) => c.label.toLowerCase())
      expect(kinds.join(' '), said).not.toMatch(/seizure|arthritis|dysplasia|diabetes/)
    }
  })

  it('returns nothing for an empty or unreadable message, not a guess', () => {
    expect(parse('')).toEqual([])
    expect(parse('   ')).toEqual([])
    expect(parse('he is a very good boy')).toEqual([])
  })

  it('produces candidates, never stored fields', () => {
    // SPEC: "an alternate entry to the same capture functions, not a fork".
    // Everything here goes through the same confirm-chips as the vet-record
    // extractor, and nothing bypasses them.
    for (const c of parse('30kg and neutered')) {
      expect(c).toHaveProperty('sourceText')
      expect(c).toHaveProperty('confidence')
      expect(c).not.toHaveProperty('provenance')
    }
  })
})
