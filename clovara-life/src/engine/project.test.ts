import { describe, expect, it } from 'vitest'
import { project, ageInYears, readBodyCondition } from './project'
import { DEMO_PETS } from '../data/demoPets'
import {
  ALL_BREEDS,
  findBreed,
  DOG_BREEDS,
  CAT_BREEDS,
  JOINT_CONDITION_IDS,
  outdoorAgeTaper,
} from '../data/engine'
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

  it('has no illustrative dogs left after the McMillan Table S3 transcription', () => {
    // Every one of the 155 breeds in that table carries a median survival
    // figure, so a dog entry falling back to a size class now means either a
    // breed the study did not cover or a regression. Cats are a separate
    // problem — six are still waiting on the Teng 2024 feline table.
    const illustrativeDogs = DOG_BREEDS.filter((b) => b.confidence === 'illustrative')
    expect(illustrativeDogs.map((b) => b.name)).toEqual([])
  })

  it('anchors every published dog to a real median survival figure', () => {
    for (const b of DOG_BREEDS) {
      if (b.confidence !== 'published') continue
      const figures = b.evidence.map((e) => e.figure).filter(Boolean).join(' ')
      expect(figures, b.id).toMatch(/\d/)
    }
  })

  it('anchors every dog to median survival, not to life expectancy at age 0', () => {
    // The two metrics are not interchangeable: life expectancy at age 0 counts
    // puppies that die young and runs systematically below median survival. A
    // dog entry whose only figure is the former is anchored to the wrong
    // question, so every one of them now carries a McMillan median as well.
    for (const b of DOG_BREEDS) {
      const figures = b.evidence.map((e) => `${e.metric ?? ''} ${e.figure ?? ''}`).join(' | ')
      expect(figures, b.id).toMatch(/median survival/)
    }
  })

  it('keeps both Poodle entries derived, because the study pooled them', () => {
    // McMillan reports one undifferentiated "Poodle" row and leaves Body Size
    // as NA for it. Claiming that figure for either variant would assert a
    // breed-level result the study does not make.
    for (const id of ['standard-poodle', 'miniature-poodle']) {
      const b = findBreed(id)!
      expect(b.confidence, id).toBe('derived')
      expect(b.note, id).toMatch(/pooled/i)
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
      // Cats carry a fourth lever — outdoor access — that dogs do not.
      expect(p.levers.length).toBe(pet.species === 'cat' ? 4 : 3)
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

describe('outdoor access (cats)', () => {
  const cat = (over: Partial<PetProfile> = {}): PetProfile =>
    base({ species: 'cat', breedId: 'domestic-shorthair', weightLb: 10, ...over })

  const low = (p: PetProfile) => project(p, { now: NOW }).healthyYearsRange.low

  it('moves the projection in both directions around the reference', () => {
    const indoor = low(cat({ outdoorAccess: 'indoor' }))
    const both = low(cat({ outdoorAccess: 'indoor-outdoor' }))
    const outdoor = low(cat({ outdoorAccess: 'outdoor' }))
    expect(indoor).toBeGreaterThan(both)
    expect(outdoor).toBeLessThan(both)
  })

  it('treats indoor-outdoor as the reference, not indoor', () => {
    // Kent 2022 put indoor-outdoor cats level with indoor-only ones, and the
    // breed baselines are read from populations full of them. A pet saved
    // before the field existed must therefore keep the number it had.
    const unasked = project(cat({ outdoorAccess: undefined }), { now: NOW })
    const both = project(cat({ outdoorAccess: 'indoor-outdoor' }), { now: NOW })
    expect(unasked.healthyYearsRange).toEqual(both.healthyYearsRange)
    // And neither shows up in "what moved the number", because neither did.
    // A question we never put must not appear on screen as an answer.
    expect(unasked.factors.some((f) => f.label.startsWith('Outdoor access'))).toBe(false)
    expect(both.factors.some((f) => f.label.startsWith('Outdoor access'))).toBe(false)
    expect(
      project(cat({ outdoorAccess: 'indoor' }), { now: NOW }).factors.some((f) =>
        f.label.startsWith('Outdoor access'),
      ),
    ).toBe(true)
  })

  it('tapers the outdoor penalty with age, because the risk falls on young cats', () => {
    const penalty = (birthDate: string) =>
      low(cat({ birthDate, outdoorAccess: 'indoor-outdoor' })) -
      low(cat({ birthDate, outdoorAccess: 'outdoor' }))
    const kitten = penalty('2026-02-14') // ~6 months
    const middle = penalty('2020-08-14') // 6 years
    const old = penalty('2016-08-14') // 10 years
    expect(kitten).toBeGreaterThan(middle)
    expect(middle).toBeGreaterThan(old)
    // Tapered, never abolished — and never inverted into a bonus.
    expect(old).toBeGreaterThan(0)
  })

  it('stops distinguishing once the cat has outlived the projection entirely', () => {
    // Not a taper effect. Past the breed baseline the engine pins the low end
    // to the animal's actual age, which flattens every factor, not just this
    // one — a fourteen-year-old outdoor cat has demonstrably survived the risk
    // the adjustment describes, and saying otherwise would be absurd.
    const at14 = (v: PetProfile['outdoorAccess']) =>
      project(cat({ birthDate: '2012-08-14', outdoorAccess: v }), { now: NOW }).healthyYearsRange
        .low
    expect(at14('outdoor')).toBe(at14('indoor-outdoor'))
    expect(at14('outdoor')).toBeGreaterThan(14)
  })

  it('widens the range for a free-roaming cat rather than only lowering it', () => {
    const width = (v: PetProfile['outdoorAccess']) => {
      const r = project(cat({ outdoorAccess: v }), { now: NOW }).healthyYearsRange
      return r.high - r.low
    }
    expect(width('outdoor')).toBeGreaterThan(width('indoor-outdoor'))
    expect(project(cat({ outdoorAccess: 'outdoor' }), { now: NOW }).widened).toBe(true)
  })

  it('is a cat lever only, and is ignored entirely on a dog', () => {
    const catP = project(cat(), { now: NOW })
    const dogP = project(base(), { now: NOW })
    expect(catP.levers.map((l) => l.id)).toContain('outdoor')
    expect(dogP.levers.map((l) => l.id)).not.toContain('outdoor')
    expect(catP.levers.find((l) => l.id === 'outdoor')!.evidenceTier).toBe('associational')

    // A dog carrying the field by accident must not have its number moved.
    const withField = project({ ...base(), outdoorAccess: 'outdoor' }, { now: NOW })
    expect(withField.healthyYearsRange).toEqual(dogP.healthyYearsRange)
  })

  it('responds to the lever override the same way it responds to the profile', () => {
    const fromProfile = low(cat({ outdoorAccess: 'outdoor' }))
    const fromLever = project(cat({ outdoorAccess: 'indoor' }), {
      now: NOW,
      overrides: { outdoor: 'outdoor' },
    }).healthyYearsRange.low
    expect(fromLever).toBeCloseTo(fromProfile, 5)
  })

  it('keeps a stacked worst case plausible for a cat', () => {
    const worst = project(
      cat({ neutered: false, outdoorAccess: 'outdoor', birthDate: '2025-08-14' }),
      { now: NOW, overrides: { weight: 'overweight', dental: 'rarely', activity: 'low' } },
    )
    expect(worst.healthyYearsRange.low).toBeGreaterThan(2)
    expect(worst.healthyYearsRange.high).toBeGreaterThan(worst.healthyYearsRange.low)
  })
})

describe('age at neutering (dogs)', () => {
  const jointCard = (p: PetProfile) =>
    project(p, { now: NOW }).riskCards.find((r) => r.id === 'hip-dysplasia')

  it('frames the joint card for a large breed neutered early', () => {
    const card = jointCard(base({ neuterAgeBand: 'under-6m' }))
    expect(card?.context?.text).toMatch(/before six months/i)
    expect(card?.context?.source.label).toMatch(/Hart/)
  })

  it('never moves the projection, whatever the answer', () => {
    const none = project(base(), { now: NOW }).healthyYearsRange
    for (const band of ['under-6m', '6-11m', '12-23m', '24m-plus', 'unsure'] as const) {
      expect(project(base({ neuterAgeBand: band }), { now: NOW }).healthyYearsRange, band).toEqual(
        none,
      )
    }
  })

  it('stays off small breeds, where Hart found no effect', () => {
    const yorkie = base({ breedId: 'yorkshire-terrier', weightLb: 6, neuterAgeBand: 'under-6m' })
    const cards = project(yorkie, { now: NOW }).riskCards
    expect(cards.every((c) => !c.context)).toBe(true)
  })

  it('stays off cards that are not joint disorders', () => {
    const cards = project(base({ neuterAgeBand: 'under-6m' }), { now: NOW }).riskCards
    const dental = cards.find((c) => c.id === 'periodontal')
    if (dental) expect(dental.context).toBeUndefined()
    expect(cards.filter((c) => c.context).every((c) => JOINT_CONDITION_IDS.has(c.id))).toBe(true)
  })

  it('says nothing when the owner was not asked, or did not know', () => {
    expect(jointCard(base())?.context).toBeUndefined()
    expect(jointCard(base({ neuterAgeBand: 'unsure' }))?.context).toBeUndefined()
    // An intact dog has no age at neutering to reason about.
    expect(jointCard(base({ neutered: false, neuterAgeBand: 'under-6m' }))?.context).toBeUndefined()
  })
})

describe('outdoorAgeTaper', () => {
  it('holds full weight through the years the risk actually falls in', () => {
    expect(outdoorAgeTaper(0)).toBe(1)
    expect(outdoorAgeTaper(2)).toBe(1)
  })

  it('decays with age and never passes its floor or its ceiling', () => {
    expect(outdoorAgeTaper(6)).toBeLessThan(1)
    expect(outdoorAgeTaper(6)).toBeGreaterThan(outdoorAgeTaper(10))
    for (const age of [0, 1, 3, 7, 12, 20, 40]) {
      expect(outdoorAgeTaper(age), String(age)).toBeGreaterThanOrEqual(0.35)
      expect(outdoorAgeTaper(age), String(age)).toBeLessThanOrEqual(1)
    }
  })
})
