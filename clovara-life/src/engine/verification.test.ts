import { describe, expect, it } from 'vitest'
import { verify, DISCARD_THRESHOLD, type ComposedReply } from './verification'
import type { GroundedFact } from './grounding'

/**
 * Tested against a model that is ACTIVELY MISBEHAVING.
 *
 * Every fixture below is something a real model does: inventing a citation,
 * citing correctly and then saying something it must not, burying one bad
 * sentence in four good ones, returning nothing, returning rubbish. The point
 * is not that our model does these — it is that the gate holds when it does.
 */
const facts: GroundedFact[] = [
  { id: 'condition-hip', claim: 'Hip dysplasia is on Scout\'s record.', source: { kind: 'pet-record', field: 'conditionIds' }, topics: ['hip'] },
  { id: 'risk-hip', claim: 'Labradors are watched for it from two.', source: { kind: 'breed-table', breedId: 'labrador-retriever', citation: 'strong' }, topics: ['hip'] },
  { id: 'activity', claim: 'You described Scout as not very active.', source: { kind: 'pet-record', field: 'activity' }, topics: ['walk'] },
]

const reply = (sentences: { text: string; citesFactIds: string[] }[], over: Partial<ComposedReply> = {}): ComposedReply => ({
  sentences,
  routeTo: 'none',
  ...over,
})

const run = (r: ComposedReply) => verify(r, facts, 'Scout')

describe('citation is compulsory', () => {
  it('drops a sentence that cites nothing', () => {
    const v = run(reply([{ text: 'Scout will probably be fine.', citesFactIds: [] }]))
    expect(v.sentences).toHaveLength(0)
    expect(v.dropped[0].reason).toBe('uncited')
  })

  it('drops a sentence citing a fact that does not exist', () => {
    // A model that invents an id has invented the sentence with it.
    const v = run(reply([{ text: 'His last blood test was normal.', citesFactIds: ['bloods-2024'] }]))
    expect(v.dropped[0].reason).toBe('unknown-fact')
  })

  it('drops a sentence that mixes one real citation with one invented', () => {
    const v = run(
      reply([{ text: 'Hip dysplasia is on file and his bloods were clear.', citesFactIds: ['condition-hip', 'bloods-2024'] }]),
    )
    expect(v.dropped[0].reason).toBe('unknown-fact')
  })

  it('keeps a properly cited sentence', () => {
    const v = run(reply([{ text: 'Hip dysplasia is on Scout\'s record.', citesFactIds: ['condition-hip'] }]))
    expect(v.sentences).toHaveLength(1)
    expect(v.discarded).toBe(false)
  })
})

describe('a true citation does not make anything sayable', () => {
  it('drops a diagnosis even when correctly cited', () => {
    const v = run(
      reply([{ text: 'That sounds like his hip dysplasia getting worse.', citesFactIds: ['condition-hip'] }]),
    )
    expect(v.dropped[0].reason).toBe('diagnostic')
  })

  it('drops speculation, however hedged', () => {
    for (const text of [
      'It could be arthritis.',
      'This is most likely the hip.',
      'It appears to be progressing.',
      'My guess is the joint.',
    ]) {
      const v = run(reply([{ text, citesFactIds: ['condition-hip'] }]))
      expect(v.dropped[0]?.reason, text).toBe('diagnostic')
    }
  })

  it('drops dosing and home treatment', () => {
    for (const text of [
      'You can give him 200mg of it.',
      'Give her half a tablet twice daily.',
      'You could induce vomiting at home.',
      'It is safe to give a little paracetamol.',
    ]) {
      const v = run(reply([{ text, citesFactIds: ['condition-hip'] }]))
      expect(v.dropped[0]?.reason, text).toBe('dosing')
    }
  })

  it('drops a promise of a longer life', () => {
    const v = run(reply([{ text: 'Keeping him lean will add years.', citesFactIds: ['activity'] }]))
    expect(v.dropped[0].reason).toBe('longer-life')
  })
})

describe('the proportion gate', () => {
  it('keeps a reply where one sentence in four failed', () => {
    const v = run(
      reply([
        { text: 'Hip dysplasia is on his record.', citesFactIds: ['condition-hip'] },
        { text: 'Labradors are watched from two.', citesFactIds: ['risk-hip'] },
        { text: 'You said he is not very active.', citesFactIds: ['activity'] },
        { text: 'It is probably arthritis.', citesFactIds: ['condition-hip'] },
      ]),
    )
    expect(v.discarded).toBe(false)
    expect(v.sentences).toHaveLength(3)
    expect(v.dropped).toHaveLength(1)
  })

  it('discards the whole reply when half of it failed', () => {
    // A paragraph with its middle removed reads as though we are hiding
    // something, and it is evidence the model was not doing what was asked.
    const v = run(
      reply([
        { text: 'Hip dysplasia is on his record.', citesFactIds: ['condition-hip'] },
        { text: 'It sounds like it is getting worse.', citesFactIds: ['condition-hip'] },
        { text: 'Give him 200mg twice daily.', citesFactIds: ['condition-hip'] },
        { text: 'Labradors are watched from two.', citesFactIds: ['risk-hip'] },
      ]),
    )
    expect(v.discarded).toBe(true)
    expect(v.sentences).toHaveLength(0)
    expect(v.fallback).toMatch(/could not put together an answer/i)
  })

  it('the threshold is a third, and is a documented decision', () => {
    expect(DISCARD_THRESHOLD).toBeCloseTo(1 / 3, 5)
  })
})

describe('what it shows when nothing survives', () => {
  it('blames itself rather than the owner', () => {
    const v = run(reply([{ text: 'Probably fine.', citesFactIds: [] }]))
    expect(v.fallback).toMatch(/our problem rather than yours/i)
  })

  it('never reassures in the fallback', () => {
    const v = run(reply([{ text: 'Probably fine.', citesFactIds: [] }]))
    expect(v.fallback).not.toMatch(/\b(fine|nothing to worry|not serious|no need)\b/i)
    expect(v.fallback).toMatch(/worth a call to your vet/i)
  })
})

describe('routing survives verification', () => {
  it('keeps vet-now even when the prose is discarded', () => {
    // The judgement that this needs a vet is not the part we distrust.
    const v = run(
      reply([{ text: 'It is probably an emergency.', citesFactIds: [] }], { routeTo: 'vet-now' }),
    )
    expect(v.discarded || v.sentences.length === 0).toBe(true)
    expect(v.route).toBe('vet-now')
  })

  it('does not invent a route the model did not give', () => {
    expect(run(reply([{ text: 'Hip is on file.', citesFactIds: ['condition-hip'] }])).route).toBe('none')
  })
})

describe('rubbish from the model', () => {
  it('survives an empty reply', () => {
    const v = run(reply([]))
    expect(v.sentences).toHaveLength(0)
    expect(v.fallback).toBeTruthy()
  })

  it('survives missing and malformed fields without throwing', () => {
    for (const bad of [
      { sentences: null },
      { sentences: [null] },
      { sentences: [{ text: '', citesFactIds: ['condition-hip'] }] },
      { sentences: [{ text: 'x', citesFactIds: 'not-an-array' }] },
      {},
    ]) {
      expect(() => verify(bad as unknown as ComposedReply, facts, 'Scout')).not.toThrow()
    }
  })

  it('treats a non-array citation field as uncited rather than trusting it', () => {
    const v = verify(
      { sentences: [{ text: 'Something.', citesFactIds: 'condition-hip' }] } as unknown as ComposedReply,
      facts,
      'Scout',
    )
    expect(v.sentences).toHaveLength(0)
  })
})
