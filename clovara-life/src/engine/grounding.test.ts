import { describe, expect, it } from 'vitest'
import { allFacts, buildGroundingSet, composeRecall } from './grounding'
import { project } from './project'
import type { PetProfile } from '../data/types'

const NOW = new Date('2026-09-24T12:00:00Z')
const pet = (over: Partial<PetProfile> = {}): PetProfile => ({
  id: 'p',
  name: 'Scout',
  species: 'dog',
  breedId: 'labrador-retriever',
  birthDate: '2019-04-02',
  sex: 'female',
  weightLb: 68,
  conditionIds: [],
  ...over,
})
const ground = (p: PetProfile, said: string) =>
  buildGroundingSet(p, project(p, { now: NOW }), said, NOW)
const recall = (p: PetProfile, said: string) => composeRecall(p, ground(p, said))

describe('every fact carries a source', () => {
  it('and a provenance wherever a person supplied it', () => {
    const facts = allFacts(
      pet({ conditionIds: ['hip-dysplasia'], activity: 'low', dental: 'rarely' }),
      project(pet(), { now: NOW }),
    )
    expect(facts.length).toBeGreaterThan(4)
    for (const f of facts) {
      expect(f.source, f.id).toBeTruthy()
      expect(f.claim.length, f.id).toBeGreaterThan(10)
      if (f.source.kind === 'pet-record' || f.source.kind === 'care-note') {
        expect(f.provenance, f.id).toBe('owner_declared')
      }
    }
  })

  it('separates what the owner said from what a table says', () => {
    // Different kinds of claim, and the difference is what makes recall
    // trustworthy rather than merely fluent.
    const facts = allFacts(pet({ conditionIds: ['hip-dysplasia'] }), project(pet(), { now: NOW }))
    const owner = facts.find((f) => f.id === 'condition-hip-dysplasia')!
    const table = facts.find((f) => f.id.startsWith('risk-'))!
    expect(owner.source.kind).toBe('pet-record')
    expect(owner.provenance).toBe('owner_declared')
    expect(table.source.kind).toBe('breed-table')
    expect(table.provenance).toBeUndefined()
  })
})

describe('retrieval', () => {
  it('finds the weight when somebody asks about weight', () => {
    const s = ground(pet(), 'Do you think she is putting on weight?')
    expect(s.facts.map((f) => f.id)).toContain('weight')
  })

  it('finds a declared condition by name', () => {
    const s = ground(pet({ conditionIds: ['hip-dysplasia'] }), 'is her hip getting worse?')
    expect(s.facts.some((f) => f.id === 'condition-hip-dysplasia')).toBe(true)
  })

  it('finds the medication note somebody wrote for a sitter', () => {
    const s = ground(pet({ careNotes: { meds: 'Half a tablet with breakfast' } }), 'is she still on her tablets?')
    expect(s.facts.map((f) => f.id)).toContain('meds')
  })

  it('finds the routine when somebody says she is slowing down', () => {
    const s = ground(pet({ activity: 'low' }), 'She has been slowing down on walks')
    expect(s.facts.map((f) => f.id)).toContain('activity')
  })

  it('returns nothing for an unrelated question rather than reaching', () => {
    const s = ground(pet(), 'what is the weather like')
    expect(s.facts).toHaveLength(0)
  })

  it('returns nothing for an empty utterance', () => {
    expect(ground(pet(), '').facts).toHaveLength(0)
    expect(ground(pet(), '   ').facts).toHaveLength(0)
  })

  it('reports how much it holds, not just what matched', () => {
    const s = ground(pet({ conditionIds: ['hip-dysplasia'], activity: 'low' }), 'weight')
    expect(s.total).toBeGreaterThan(s.facts.length)
  })
})

describe('composition says only what the facts say', () => {
  it('opens by naming the record, not by offering an opinion', () => {
    const r = recall(pet({ conditionIds: ['hip-dysplasia'] }), 'her hip seems sore')
    expect(r.opening).toMatch(/already on Scout's record/i)
  })

  it('NEVER diagnoses, ranks or speculates', () => {
    for (const said of [
      'her hip seems sore',
      'she is slowing down on walks',
      'her breath smells',
      'she is off her food and losing weight',
    ]) {
      const r = recall(
        pet({ conditionIds: ['hip-dysplasia'], activity: 'low', dental: 'rarely' }),
        said,
      )
      const blob = [r.opening, r.closing, ...r.facts.map((f) => f.claim)].join(' ')
      expect(blob, said).not.toMatch(
        /\b(sounds like|probably|likely|it could be|I think|diagnos|suggests|consistent with|most likely)\b/i,
      )
    }
  })

  it('says plainly that it is recall and not an opinion', () => {
    const r = recall(pet({ conditionIds: ['hip-dysplasia'] }), 'her hip seems sore')
    expect(r.closing).toMatch(/recall, not an opinion/i)
    expect(r.closing).toMatch(/have not examined/i)
  })

  it('routes to a vet when the record has something to say', () => {
    expect(recall(pet({ conditionIds: ['hip-dysplasia'] }), 'her hip').route).toBe('vet-soon')
  })

  it('does not route to a vet for a routine question', () => {
    expect(recall(pet({ activity: 'low' }), 'how much does she walk').route).toBe('none')
  })

  it('says "I do not know" honestly when nothing matched (invariant 9)', () => {
    const r = recall(pet(), 'what is the weather like')
    expect(r.opening).toBeNull()
    expect(r.facts).toHaveLength(0)
    expect(r.closing).toMatch(/none of them speak to what you have described/i)
    expect(r.closing).toMatch(/gap in what we know, not a judgement/i)
    // And it must not quietly reassure on the way out.
    expect(r.closing).not.toMatch(/\b(fine|nothing to worry|not serious|probably ok)\b/i)
  })

  it('never claims a longer life (VISION vocabulary)', () => {
    const r = recall(pet({ conditionIds: ['hip-dysplasia'], activity: 'low' }), 'her hip and her walking')
    const blob = [r.opening, r.closing, ...r.facts.map((f) => f.claim)].join(' ')
    expect(blob).not.toMatch(/live longer|longer life|extra years|add years/i)
  })
})

describe('the grounding rule itself', () => {
  it('composition can only use facts that retrieval returned', () => {
    // The rule the file exists to enforce, asserted rather than trusted: every
    // fact in the reply must be in the set the retrieval produced.
    const p = pet({ conditionIds: ['hip-dysplasia'], activity: 'low', dental: 'rarely' })
    const set = ground(p, 'her hip and her teeth and her walking')
    const r = composeRecall(p, set)
    const ids = new Set(set.facts.map((f) => f.id))
    for (const f of r.facts) expect(ids.has(f.id), f.id).toBe(true)
  })
})
