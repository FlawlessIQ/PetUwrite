import { describe, expect, it } from 'vitest'
import { accuracyLine, planAccuracy } from './accuracy'
import { project } from './project'
import { ALL_BREEDS } from '../data/engine'
import type { PetProfile } from '../data/types'

const NOW = new Date('2026-09-23T12:00:00Z')

/** Tier 0 only — what SPEC §4.1 collects before the reveal. */
const tier0 = (over: Partial<PetProfile> = {}): PetProfile => ({
  id: 'p1',
  name: 'Scout',
  species: 'dog',
  breedId: 'labrador-retriever',
  birthDate: '2021-04-02',
  sex: 'female',
  weightLb: 0,
  conditionIds: [],
  ...over,
})

/** Everything a Labrador owner can tell us. */
const complete = (over: Partial<PetProfile> = {}): PetProfile =>
  tier0({
    weightLb: 70,
    conditionIds: ['hip-dysplasia'],
    neutered: true,
    neuterAgeBand: 'under-6m',
    activity: 'high',
    dental: 'daily',
    diet: 'measured',
    ...over,
  })

describe('planAccuracy — the shape of the number', () => {
  it('scores Tier 0 as real knowledge, not as zero', () => {
    // The breed baseline and the age ARE the projection; everything in Tier 1
    // adjusts a number those two produced. Telling someone their reveal is 0%
    // sharp would be false, and false at the moment they are most impressed.
    const a = planAccuracy(tier0())
    expect(a.score).toBe(40)
    expect(a.showOnHome).toBe(true)
  })

  it("lands SPEC §4.2's own example in the middle of Tier 1", () => {
    // "Max's plan: 68% sharp — add his body condition to reach 80%."
    const partway = planAccuracy(
      tier0({ neutered: true, activity: 'high', dental: 'daily', diet: 'measured', conditionsReviewed: true }),
    )
    expect(partway.score).toBeGreaterThan(55)
    expect(partway.score).toBeLessThan(90)
    expect(partway.nextBest?.field).toBe('weightLb')
  })

  it('reaches the ceiling when everything applicable is answered', () => {
    const a = planAccuracy(complete())
    expect(a.score).toBe(100)
    expect(a.nextBest).toBeNull()
    expect(a.showOnHome).toBe(false)
  })

  it('only hides from Home above 90', () => {
    expect(planAccuracy(tier0()).showOnHome).toBe(true)
    expect(planAccuracy(complete()).showOnHome).toBe(false)
  })

  it('rises monotonically as fields are answered, never falls', () => {
    let last = planAccuracy(tier0()).score
    const steps: Partial<PetProfile>[] = [
      { neutered: true },
      { dental: 'daily' },
      { activity: 'high' },
      { diet: 'measured' },
      { conditionsReviewed: true },
      { weightLb: 70 },
    ]
    let p = tier0()
    for (const step of steps) {
      p = { ...p, ...step }
      const now = planAccuracy(p).score
      expect(now, JSON.stringify(step)).toBeGreaterThanOrEqual(last)
      last = now
    }
  })
})

describe('planAccuracy — what it points at next', () => {
  it('names body condition first, because it moves the projection most', () => {
    const a = planAccuracy(tier0())
    expect(a.nextBest?.field).toBe('weightLb')
    expect(a.scoreWithNextBest).toBeGreaterThan(a.score)
  })

  it('the next-best field really is the highest-scoring one left', () => {
    const a = planAccuracy(tier0({ weightLb: 70 }))
    const unanswered = a.fields.filter((f) => !f.answered)
    const best = Math.max(...unanswered.map((f) => f.points))
    expect(a.nextBest!.points).toBe(best)
  })

  it('every benefit line says what it does for the pet, not "complete your profile"', () => {
    for (const f of planAccuracy(tier0()).fields) {
      expect(f.benefit.length, f.field).toBeGreaterThan(20)
      expect(f.benefit, f.field).not.toMatch(/complete your profile|finish setting up|100%/i)
    }
  })
})

describe('planAccuracy — only asks what applies', () => {
  it('never asks a dog about outdoor access', () => {
    const fields = planAccuracy(tier0()).fields.map((f) => f.field)
    expect(fields).not.toContain('outdoorAccess')
  })

  it('asks a cat about outdoor access, and weights it heavily', () => {
    const cat = planAccuracy(
      tier0({ species: 'cat', breedId: 'persian', weightLb: 0 }),
    )
    const outdoor = cat.fields.find((f) => f.field === 'outdoorAccess')
    expect(outdoor).toBeTruthy()
    expect(outdoor!.points).toBeGreaterThan(10)
  })

  it('asks age-at-neuter only of a large neutered dog', () => {
    const has = (p: PetProfile) =>
      planAccuracy(p).fields.some((f) => f.field === 'neuterAgeBand')
    expect(has(complete())).toBe(true)
    // Small breed: Hart found no effect, so it is never asked.
    expect(has(complete({ breedId: 'yorkshire-terrier', weightLb: 6 }))).toBe(false)
    // Intact: there is no age at neutering to ask about.
    expect(has(complete({ neutered: false }))).toBe(false)
  })

  it('a small dog can still reach 100 without the question it is never asked', () => {
    const yorkie = complete({ breedId: 'yorkshire-terrier', weightLb: 6, neuterAgeBand: undefined })
    expect(planAccuracy(yorkie).score).toBe(100)
  })
})

describe('planAccuracy — "none that I know of" is an answer', () => {
  it('stops asking about conditions once the owner has reviewed the list', () => {
    // Invariant 9. Without this the meter would nag forever at the owner of a
    // healthy pet, which punishes them for good news.
    const before = planAccuracy(tier0())
    const after = planAccuracy(tier0({ conditionsReviewed: true }))
    expect(after.score).toBeGreaterThan(before.score)
    expect(after.fields.find((f) => f.field === 'conditionIds')!.answered).toBe(true)
  })

  it('declaring a condition also counts, without needing the flag', () => {
    const a = planAccuracy(tier0({ conditionIds: ['hip-dysplasia'] }))
    expect(a.fields.find((f) => f.field === 'conditionIds')!.answered).toBe(true)
  })

  it('treats a recorded "not neutered" as answered, not as missing', () => {
    // `false` is something the owner said. Absent is not.
    expect(planAccuracy(tier0({ neutered: false })).fields.find((f) => f.field === 'neutered')!.answered).toBe(true)
    expect(planAccuracy(tier0()).fields.find((f) => f.field === 'neutered')!.answered).toBe(false)
  })

  it('does not count "not sure" about neuter age as an answer', () => {
    const a = planAccuracy(complete({ neuterAgeBand: 'unsure' }))
    expect(a.fields.find((f) => f.field === 'neuterAgeBand')!.answered).toBe(false)
  })
})

describe('planAccuracy — the ceiling is honest', () => {
  it('a mixed breed cannot reach 100, however much you tell us', () => {
    const mixed = complete({ breedId: 'mixed-large', weightLb: 70 })
    const a = planAccuracy(mixed)
    expect(a.score).toBeLessThan(100)
    expect(a.ceiling?.max).toBe(85)
    expect(a.ceiling?.reason).toMatch(/size-class/i)
  })

  it('explains the ceiling rather than leaving it a mystery', () => {
    for (const breedId of ['mixed-large', 'standard-poodle']) {
      const a = planAccuracy(complete({ breedId, weightLb: 50 }))
      if (a.ceiling) {
        expect(a.ceiling.reason.length, breedId).toBeGreaterThan(40)
        expect(a.ceiling.reason, breedId).toMatch(/tops out/i)
      }
    }
  })

  it('a published breed has no ceiling at all', () => {
    expect(planAccuracy(complete()).ceiling).toBeNull()
  })

  it('never reports a score above its own ceiling', () => {
    for (const b of ALL_BREEDS) {
      const p = complete({
        species: b.species,
        breedId: b.id,
        weightLb: (b.weight.low + b.weight.high) / 2,
        outdoorAccess: b.species === 'cat' ? 'indoor' : undefined,
      })
      const a = planAccuracy(p)
      expect(a.score, b.id).toBeLessThanOrEqual(a.ceiling?.max ?? 100)
      expect(a.score, b.id).toBeGreaterThanOrEqual(0)
    }
  })
})

describe('planAccuracy — agreement with the engine', () => {
  it('every field it scores is one the engine actually reads', () => {
    // The meter must not award points for something that changes nothing —
    // that would make it a measure of engagement wearing a lab coat.
    const base = tier0({ conditionsReviewed: true })
    const engineFields = new Set(['weightLb', 'conditionIds', 'neutered', 'activity', 'dental', 'outdoorAccess'])
    for (const f of planAccuracy(base).fields) {
      // diet and neuterAgeBand are the two deliberate exceptions: they are
      // recorded and shown, and neither moves the projection. Both are the
      // lowest-weighted fields in the table.
      if (!engineFields.has(f.field)) {
        expect(['diet', 'neuterAgeBand'], f.field).toContain(f.field)
        expect(f.points, f.field).toBeLessThanOrEqual(6)
      }
    }
  })

  it('answering the top field visibly changes the projection', () => {
    // SPEC §4.2: "Each answer visibly moves the projection — this is the
    // incentive mechanic." If the highest-value field did not move it, the
    // mechanic would be a lie.
    const before = project(tier0(), { now: NOW })
    const after = project(tier0({ weightLb: 95 }), { now: NOW })
    expect(after.healthyYearsRange.low).not.toBe(before.healthyYearsRange.low)
  })

  it('is pure — same profile, same result', () => {
    const p = complete()
    expect(planAccuracy(p)).toEqual(planAccuracy(p))
  })

  it('never throws on an unknown breed', () => {
    expect(() => planAccuracy(tier0({ breedId: 'nope' }))).not.toThrow()
    expect(planAccuracy(tier0({ breedId: 'nope' })).score).toBe(0)
  })
})

describe('accuracyLine', () => {
  it('reads like the example in SPEC §4.2', () => {
    const line = accuracyLine('Max', planAccuracy(tier0()))
    expect(line).toMatch(/^Max's plan: \d+% sharp — add .+ to reach \d+%\.$/)
  })

  it('says so when there is nothing left to add', () => {
    expect(accuracyLine('Max', planAccuracy(complete()))).toMatch(/everything that moves it/i)
  })

  it('does not promise 100 to a pet that cannot reach it', () => {
    const line = accuracyLine('Max', planAccuracy(complete({ breedId: 'mixed-large' })))
    expect(line).toMatch(/as sharp as it goes/i)
    expect(line).not.toMatch(/100%/)
  })
})

describe('at the ceiling', () => {
  it('does not promise a gain that cannot happen (UAT run 1, D1)', () => {
    const a = { score: 85, scoreWithNextBest: 85, nextBest: { label: 'anything diagnosed' }, ceiling: { max: 85, reason: '' } }
    const line = accuracyLine('Luna', a as unknown as ReturnType<typeof planAccuracy>)
    expect(line).not.toMatch(/to reach 85%/)
    expect(line).toMatch(/85% sharp, as far as it goes/)
    expect(line).toMatch(/anything diagnosed would still change what it says/)
  })
})
