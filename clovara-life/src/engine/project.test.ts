import { describe, expect, it } from 'vitest'
import { project, ageInYears, readBodyCondition } from './project'
import { DEMO_PETS } from '../data/demoPets'
import { ALL_BREEDS, findBreed, DOG_BREEDS, CAT_BREEDS } from '../data/engine'
import type { PetProfile } from '../data/types'

/** Fixed clock so every assertion is deterministic. */
const NOW = new Date('2026-08-14T12:00:00Z')

const base = (over: Partial<PetProfile> = {}): PetProfile => ({
  id: 'test',
  name: 'Test',
  species: 'dog',
  breedId: 'labrador-retriever',
  birthDate: '2020-08-14',
  sex: 'male',
  neutered: true,
  weightLb: 70,
  conditionIds: [],
  activity: 'moderate',
  dental: 'weekly',
  diet: 'measured',
  ...over,
})

describe('data integrity', () => {
  it('meets the coverage bar: 25+ dog breeds and 6+ cat breeds', () => {
    expect(DOG_BREEDS.length).toBeGreaterThanOrEqual(25)
    expect(CAT_BREEDS.length).toBeGreaterThanOrEqual(6)
  })

  it('has a size-class fallback for every mixed-breed size', () => {
    const mixedDogs = DOG_BREEDS.filter((b) => b.isMixed)
    expect(mixedDogs.map((b) => b.sizeClass).sort()).toEqual(
      ['giant', 'large', 'medium', 'small', 'toy'].sort(),
    )
  })

  it('has unique ids', () => {
    const ids = ALL_BREEDS.map((b) => b.id)
    expect(new Set(ids).size).toBe(ids.length)
  })

  it('gives every breed a sane baseline, weight range, evidence and conditions', () => {
    for (const b of ALL_BREEDS) {
      expect(b.baseline.low, b.id).toBeGreaterThan(3)
      expect(b.baseline.high, b.id).toBeGreaterThan(b.baseline.low)
      expect(b.baseline.high - b.baseline.low, b.id).toBeLessThanOrEqual(4)
      expect(b.weight.high, b.id).toBeGreaterThan(b.weight.low)
      expect(b.evidence.length, b.id).toBeGreaterThan(0)
      expect(b.conditions.length, b.id).toBeGreaterThanOrEqual(3)
      for (const c of b.conditions) {
        expect(c.onset[1], `${b.id}/${c.id}`).toBeGreaterThanOrEqual(c.onset[0])
        expect(c.action.length, `${b.id}/${c.id}`).toBeGreaterThan(10)
      }
    }
  })

  it('never claims published confidence without a figure in its evidence', () => {
    for (const b of ALL_BREEDS) {
      if (b.confidence === 'published') {
        expect(b.evidence.some((e) => !!e.figure), b.id).toBe(true)
      }
    }
  })

  it('flags every illustrative breed so it can be surfaced and firmed up', () => {
    const illustrative = ALL_BREEDS.filter((b) => b.confidence === 'illustrative')
    // This is expected to be non-empty. The point is that it is enumerable.
    for (const b of illustrative) {
      expect(b.note, b.id).toBeTruthy()
    }
  })
})

describe('ageInYears', () => {
  it('computes whole years', () => {
    expect(ageInYears('2020-08-14', NOW)).toBeCloseTo(6, 1)
  })

  it('handles a pet born today', () => {
    expect(ageInYears('2026-08-14', NOW)).toBeLessThan(0.1)
  })

  it('never returns negative for a future date', () => {
    expect(ageInYears('2027-01-01', NOW)).toBe(0)
  })
})

describe('readBodyCondition', () => {
  const lab = findBreed('labrador-retriever')!
  it('reads inside the breed range as ideal', () => {
    expect(readBodyCondition(70, lab)).toBe('ideal')
  })
  it('reads well above the range as overweight', () => {
    expect(readBodyCondition(95, lab)).toBe('overweight')
  })
  it('reads well below the range as lean', () => {
    expect(readBodyCondition(45, lab)).toBe('lean')
  })
})

describe('demo pets', () => {
  for (const pet of DEMO_PETS) {
    it(`${pet.name} projects a plausible, well-formed result`, () => {
      const p = project(pet, { now: NOW })
      expect(p.healthyYearsRange.high).toBeGreaterThan(p.healthyYearsRange.low)
      expect(p.healthyYearsRange.low).toBeGreaterThan(2)
      expect(p.healthyYearsRange.high).toBeLessThan(22)
      expect(p.stages.length).toBe(4)
      expect(p.riskCards.length).toBeGreaterThanOrEqual(4)
      expect(p.riskCards.length).toBeLessThanOrEqual(5)
      expect(p.levers.length).toBe(3)
      expect(p.currentStage).toBeTruthy()
      expect(p.arcPosition).toBeGreaterThanOrEqual(0)
      expect(p.arcPosition).toBeLessThanOrEqual(1)
    })
  }

  it('Max is a mature adult with his declared hip finding in manage mode', () => {
    const max = DEMO_PETS.find((p) => p.name === 'Max')!
    const p = project(max, { now: NOW })
    expect(p.ageYears).toBeCloseTo(6.3, 0)
    expect(p.currentStage.id).toBe('mature-adult')
    const hip = p.riskCards.find((r) => r.id === 'hip-dysplasia')
    expect(hip?.mode).toBe('manage')
    // Declared conditions must pull the low end below the untouched baseline.
    const clean = project({ ...max, conditionIds: [] }, { now: NOW })
    expect(p.healthyYearsRange.low).toBeLessThan(clean.healthyYearsRange.low)
  })

  it('Winston reads as a different breed picture, not just a smaller dog', () => {
    const winston = DEMO_PETS.find((p) => p.name === 'Winston')!
    const p = project(winston, { now: NOW })
    const airway = p.riskCards.find((r) => r.id === 'boas')
    expect(airway).toBeTruthy()
    expect(airway!.tier).toBe('high')
    // A French Bulldog should project meaningfully fewer healthy years than a
    // same-age, same-care small mixed breed.
    const mixed = project({ ...winston, breedId: 'mixed-small', weightLb: 20 }, { now: NOW })
    expect(p.healthyYearsRange.high).toBeLessThan(mixed.healthyYearsRange.high)
  })

  it('Luna uses feline life stages and feline body-condition logic', () => {
    const luna = DEMO_PETS.find((p) => p.name === 'Luna')!
    const p = project(luna, { now: NOW })
    // AAHA/AAFP 2021: mature adult is 7 to 10 for cats.
    expect(p.currentStage.id).toBe('mature-adult')
    // In cats, lean is not a bonus — this is the key species difference.
    const lean = project(luna, { now: NOW, overrides: { weight: 'lean' } })
    const ideal = project(luna, { now: NOW, overrides: { weight: 'ideal' } })
    expect(lean.healthyYearsRange.low).toBeLessThan(ideal.healthyYearsRange.low)
  })
})

describe('levers move the projection', () => {
  const pet = base({ weightLb: 70 })

  it('weight is the biggest lever in a dog', () => {
    const ideal = project(pet, { now: NOW, overrides: { weight: 'ideal' } })
    const over = project(pet, { now: NOW, overrides: { weight: 'overweight' } })
    expect(over.healthyYearsRange.low).toBeLessThan(ideal.healthyYearsRange.low)
    expect(ideal.healthyYearsRange.low - over.healthyYearsRange.low).toBeGreaterThanOrEqual(0.8)
  })

  it('the overweight penalty is larger in small breeds than large ones', () => {
    const small = base({ breedId: 'yorkshire-terrier', weightLb: 6 })
    const large = base({ breedId: 'labrador-retriever', weightLb: 70 })
    const delta = (p: PetProfile) =>
      project(p, { now: NOW, overrides: { weight: 'ideal' } }).healthyYearsRange.low -
      project(p, { now: NOW, overrides: { weight: 'overweight' } }).healthyYearsRange.low
    expect(delta(small)).toBeGreaterThan(delta(large))
  })

  it('dental and activity move the number, but less than weight', () => {
    const ref = project(pet, { now: NOW })
    const dental = project(pet, { now: NOW, overrides: { dental: 'daily' } })
    const activity = project(pet, { now: NOW, overrides: { activity: 'high' } })
    expect(dental.healthyYearsRange.low).toBeGreaterThan(ref.healthyYearsRange.low)
    expect(activity.healthyYearsRange.low).toBeGreaterThan(ref.healthyYearsRange.low)

    const weightSwing =
      project(pet, { now: NOW, overrides: { weight: 'ideal' } }).healthyYearsRange.low -
      project(pet, { now: NOW, overrides: { weight: 'overweight' } }).healthyYearsRange.low
    const dentalSwing =
      project(pet, { now: NOW, overrides: { dental: 'daily' } }).healthyYearsRange.low -
      project(pet, { now: NOW, overrides: { dental: 'rarely' } }).healthyYearsRange.low
    expect(weightSwing).toBeGreaterThan(dentalSwing)
  })

  it('labels each lever with its real evidence tier', () => {
    const p = project(pet, { now: NOW })
    expect(p.levers.find((l) => l.id === 'weight')!.evidenceTier).toBe('strong')
    expect(p.levers.find((l) => l.id === 'dental')!.evidenceTier).toBe('associational')
    expect(p.levers.find((l) => l.id === 'activity')!.evidenceTier).toBe('directional')
  })

  it('caps the total swing so stacked inputs stay plausible', () => {
    const worst = project(
      base({ neutered: false }),
      { now: NOW, overrides: { weight: 'overweight', dental: 'rarely', activity: 'low' } },
    )
    const bestCase = project(
      base(),
      { now: NOW, overrides: { weight: 'ideal', dental: 'daily', activity: 'high' } },
    )
    const swing = bestCase.healthyYearsRange.low - worst.healthyYearsRange.low
    expect(swing).toBeLessThanOrEqual(4.5)
  })
})

describe('edge cases', () => {
  it('a very young puppy still gets a full journey', () => {
    const p = project(base({ birthDate: '2026-06-01' }), { now: NOW })
    expect(p.ageYears).toBeLessThan(0.5)
    expect(p.currentStage.id).toBe('puppy')
    expect(p.stages.filter((s) => s.status === 'future').length).toBe(3)
    expect(p.stages.every((s) => s.recommendations.length >= 2)).toBe(true)
  })

  it('a very old pet never shows a range it has already passed', () => {
    const p = project(base({ birthDate: '2009-08-14' }), { now: NOW })
    expect(p.ageYears).toBeGreaterThan(16)
    expect(p.healthyYearsRange.low).toBeGreaterThan(p.ageYears)
    expect(p.healthyYearsRange.high).toBeGreaterThan(p.healthyYearsRange.low)
    expect(p.currentStage.id).toBe('senior')
    expect(p.arcPosition).toBeLessThanOrEqual(1)
  })

  it('an overweight senior stacks correctly without going implausible', () => {
    const p = project(
      base({ breedId: 'mixed-large', birthDate: '2015-08-14', weightLb: 130, conditionIds: ['arthritis', 'periodontal'] }),
      { now: NOW },
    )
    expect(p.bodyCondition).toBe('overweight')
    expect(p.currentStage.id).toBe('senior')
    expect(p.healthyYearsRange.low).toBeGreaterThan(2)
    expect(p.widened).toBe(true)
    expect(p.healthyYearsRange.high - p.healthyYearsRange.low).toBeGreaterThan(1)
  })

  it('an unknown breed widens the range rather than pretending to precision', () => {
    const known = project(base({ breedId: 'labrador-retriever' }), { now: NOW })
    const mixed = project(base({ breedId: 'mixed-large' }), { now: NOW })
    const width = (r: { low: number; high: number }) => r.high - r.low
    expect(mixed.widened).toBe(true)
    expect(width(mixed.healthyYearsRange)).toBeGreaterThan(width(known.healthyYearsRange))
  })

  it('missing weight widens rather than guessing', () => {
    const p = project(base({ weightLb: 0 }), { now: NOW })
    expect(p.widened).toBe(true)
  })

  it('is pure — same input, same output', () => {
    const pet = base()
    expect(project(pet, { now: NOW })).toEqual(project(pet, { now: NOW }))
  })

  it('throws clearly on an unknown breed id', () => {
    expect(() => project(base({ breedId: 'nope' }), { now: NOW })).toThrow(/Unknown breed/)
  })

  it('every breed in the database projects without error', () => {
    for (const b of ALL_BREEDS) {
      const p = project(
        base({ species: b.species, breedId: b.id, weightLb: (b.weight.low + b.weight.high) / 2 }),
        { now: NOW },
      )
      expect(p.healthyYearsRange.high, b.id).toBeGreaterThan(p.healthyYearsRange.low)
      expect(p.riskCards.length, b.id).toBeGreaterThanOrEqual(3)
    }
  })
})
