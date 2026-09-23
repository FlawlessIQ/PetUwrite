import { afterEach, describe, expect, it } from 'vitest'
import {
  EXTRACTION_ENABLED,
  StubExtractor,
  confirm,
  extractionProvider,
  ordered,
  setExtractionProvider,
  type Candidate,
  type ExtractionProvider,
} from './provider'

const NOW = new Date('2026-09-23T12:00:00Z')
const candidate = (over: Partial<Candidate> = {}): Candidate => ({
  id: 'c1',
  kind: 'vaccine',
  label: 'DHP, 12 March 2026',
  sourceText: 'DHP 12/03/2026 Riverside Vets',
  confidence: 0.8,
  value: { doseId: 'dog-dhp-1', givenOn: '2026-03-12' },
  ...over,
})

afterEach(() => setExtractionProvider(StubExtractor))

describe('the flag', () => {
  it('is off, because two non-engineering things gate it', () => {
    // SPEC §7's security review, and an LLM key. Both are Conor's.
    expect(EXTRACTION_ENABLED).toBe(false)
  })
})

describe('the stub', () => {
  it('returns nothing and says why', async () => {
    const r = await StubExtractor.extract({ name: 'card.jpg', type: 'image/jpeg', size: 1000 })
    expect(r.candidates).toHaveLength(0)
    expect(r.unavailableReason).toMatch(/security review/i)
  })

  it('NEVER invents plausible-looking sample candidates', async () => {
    // A stub returning "Rabies, 12 March 2025" would put a fabricated
    // vaccination in front of an owner to confirm, and a confirmed fabrication
    // is indistinguishable from a real record forever after.
    const r = await StubExtractor.extract({ name: 'card.jpg', type: 'image/jpeg', size: 1000 })
    expect(r.candidates).toEqual([])
    expect(StubExtractor.available).toBe(false)
  })

  it('says it would rather hold nothing than hold it badly', async () => {
    const r = await StubExtractor.extract({ name: 'x.pdf', type: 'application/pdf', size: 10 })
    expect(r.unavailableReason).toMatch(/rather not hold them at all/i)
  })
})

describe('confirmation is the only path to data (invariant 8)', () => {
  it('stamps extracted_confirmed', () => {
    const f = confirm(candidate(), NOW)
    expect(f.provenance).toBe('extracted_confirmed')
    expect(f.confirmedAt).toBe(NOW.toISOString())
  })

  it('NEVER stamps vet_verified', () => {
    // An owner reading a scan and tapping yes is not a veterinary attestation.
    // Conflating them would launder a guess into a medical fact.
    for (const kind of ['vaccine', 'condition', 'weight', 'visit'] as const) {
      expect(confirm(candidate({ kind }), NOW).provenance).not.toBe('vet_verified')
    }
  })

  it('keeps the source text, so a confirmed value can be traced back', () => {
    expect(confirm(candidate(), NOW).sourceText).toBe('DHP 12/03/2026 Riverside Vets')
  })

  it('carries the structured value through untouched', () => {
    expect(confirm(candidate(), NOW).value).toEqual({ doseId: 'dog-dhp-1', givenOn: '2026-03-12' })
  })
})

describe('ordering', () => {
  it('puts the most confident first', () => {
    const list = [candidate({ id: 'a', confidence: 0.2 }), candidate({ id: 'b', confidence: 0.9 })]
    expect(ordered(list).map((c) => c.id)).toEqual(['b', 'a'])
  })

  it('is stable for ties', () => {
    const list = [candidate({ id: 'a', confidence: 0.5 }), candidate({ id: 'b', confidence: 0.5 })]
    expect(ordered(list).map((c) => c.id)).toEqual(['a', 'b'])
  })

  it('does not mutate the input', () => {
    const list = [candidate({ id: 'a', confidence: 0.2 }), candidate({ id: 'b', confidence: 0.9 })]
    ordered(list)
    expect(list.map((c) => c.id)).toEqual(['a', 'b'])
  })
})

describe('the seam', () => {
  it('swaps for a real extractor without a surface knowing', () => {
    const real: ExtractionProvider = {
      id: 'llm',
      available: true,
      async extract() {
        return { candidates: [candidate()], providerId: 'llm' }
      },
    }
    setExtractionProvider(real)
    expect(extractionProvider().id).toBe('llm')
    expect(extractionProvider().available).toBe(true)
  })
})
