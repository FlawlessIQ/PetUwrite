import { describe, expect, it } from 'vitest'
import { project } from './project'
import {
  buildCompanion,
  buildCoverage as buildCoverageOrNull,
  buildHome,
  buildRewards as buildRewardsOrNull,
  clovaraScore,
} from './platform'
import { recommendProducts } from './shop'
import { DEMO_PETS } from '../data/demoPets'
import { ALL_BREEDS } from '../data/engine'
import { PRODUCTS } from '../data/products'
import { REDEMPTIONS, POINT_RULES } from '../data/rewards'
import { RIDER_ITEMS } from '../data/coverage'
import type { PetProfile } from '../data/types'

// Every pet priced in this file is alive; a remembered pet gets null (remember.test.ts).
const buildCoverage = (...a: Parameters<typeof buildCoverageOrNull>) => buildCoverageOrNull(...a)!
const buildRewards = (...a: Parameters<typeof buildRewardsOrNull>) => buildRewardsOrNull(...a)!

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

const p = (profile: PetProfile) => project(profile, { now: NOW })

describe('catalog integrity', () => {
  it('has unique product ids and every product is flagged illustrative', () => {
    const ids = PRODUCTS.map((x) => x.id)
    expect(new Set(ids).size).toBe(ids.length)
    for (const item of PRODUCTS) {
      expect(item.confidence, item.id).toBe('illustrative')
      expect(item.evidenceNote.length, item.id).toBeGreaterThan(40)
      expect(item.memberPrice, item.id).toBeLessThanOrEqual(item.price)
      expect(item.species.length, item.id).toBeGreaterThan(0)
    }
  })

  it('only targets condition ids that actually exist in the breed database', () => {
    const known = new Set(ALL_BREEDS.flatMap((b) => b.conditions.map((c) => c.id)))
    for (const item of PRODUCTS) {
      for (const t of item.targets) {
        expect(known.has(t), `${item.id} targets unknown condition "${t}"`).toBe(true)
      }
    }
  })

  it('never offers a redemption against premium — this is the regulatory line', () => {
    for (const r of REDEMPTIONS) {
      expect(['product', 'care']).toContain(r.kind)
      expect(r.label.toLowerCase()).not.toMatch(/premium/)
    }
  })

  it('weights point rules so the projection-moving behaviours are represented', () => {
    expect(POINT_RULES.filter((r) => r.movesProjection).length).toBeGreaterThanOrEqual(3)
  })

  it('covers every life stage with at least one rider item, per species', () => {
    for (const stage of ['puppy', 'young-adult', 'mature-adult', 'senior']) {
      expect(RIDER_ITEMS.some((r) => r.species.includes('dog') && r.stages.includes(stage)), `dog/${stage}`).toBe(true)
    }
    for (const stage of ['kitten', 'young-adult', 'mature-adult', 'senior']) {
      expect(RIDER_ITEMS.some((r) => r.species.includes('cat') && r.stages.includes(stage)), `cat/${stage}`).toBe(true)
    }
  })
})

describe('clovara score', () => {
  it('stays within 0 and 100 for every breed at every body condition', () => {
    for (const b of ALL_BREEDS) {
      for (const w of [b.weight.low * 0.7, (b.weight.low + b.weight.high) / 2, b.weight.high * 1.4]) {
        const profile = base({ species: b.species, breedId: b.id, weightLb: w })
        const s = clovaraScore(profile, p(profile))
        expect(s.value, `${b.id}@${w}`).toBeGreaterThanOrEqual(0)
        expect(s.value, `${b.id}@${w}`).toBeLessThanOrEqual(100)
      }
    }
  })

  it('bands always sum to the score, and maxima sum to 100', () => {
    const profile = base()
    const s = clovaraScore(profile, p(profile))
    expect(s.bands.reduce((a, b) => a + b.earned, 0)).toBe(s.value)
    expect(s.bands.reduce((a, b) => a + b.max, 0)).toBe(100)
  })

  it('weights body condition heaviest, matching the engine evidence tiers', () => {
    const profile = base()
    const s = clovaraScore(profile, p(profile))
    const weight = s.bands.find((b) => b.id === 'weight')!
    for (const other of s.bands.filter((b) => b.id !== 'weight')) {
      expect(weight.max).toBeGreaterThan(other.max)
    }
  })

  it('rewards the best routine above the worst', () => {
    const good = base({ dental: 'daily', activity: 'high', diet: 'measured' })
    const bad = base({ dental: 'rarely', activity: 'low', diet: 'free-fed', neutered: false })
    expect(clovaraScore(good, p(good)).value).toBeGreaterThan(clovaraScore(bad, p(bad)).value)
  })

  it('names the biggest gap so the nudge has something to point at', () => {
    const profile = base({ dental: 'rarely', activity: 'high', diet: 'measured' })
    const s = clovaraScore(profile, p(profile))
    expect(s.biggestGap?.id).toBe('dental')
  })

  it('does not treat lean as ideal in a cat, the way it would in a dog', () => {
    const cat = base({ species: 'cat', breedId: 'domestic-shorthair', weightLb: 6 })
    const catIdeal = base({ species: 'cat', breedId: 'domestic-shorthair', weightLb: 10 })
    expect(clovaraScore(cat, p(cat)).value).toBeLessThan(clovaraScore(catIdeal, p(catIdeal)).value)
  })
})

describe('shop recommendations', () => {
  it('puts a matched product above an unmatched one', () => {
    const profile = base({ conditionIds: ['hip-dysplasia'] })
    const recs = recommendProducts(profile, p(profile))
    const joint = recs.findIndex((r) => r.id === 'joint-chews')
    const shampoo = recs.findIndex((r) => r.id === 'oat-shampoo')
    expect(joint).toBeGreaterThanOrEqual(0)
    expect(joint).toBeLessThan(shampoo)
  })

  it('gives every recommendation a why line', () => {
    for (const pet of DEMO_PETS) {
      for (const rec of recommendProducts(pet, p(pet))) {
        expect(rec.why.length, `${pet.name}/${rec.id}`).toBeGreaterThan(8)
      }
    }
  })

  it('never shows a dog product to a cat owner', () => {
    const luna = DEMO_PETS.find((x) => x.name === 'Luna')!
    for (const rec of recommendProducts(luna, p(luna))) {
      expect(rec.species, rec.id).toContain('cat')
    }
  })

  it('surfaces a different top product for Winston than for Max', () => {
    const max = DEMO_PETS.find((x) => x.name === 'Max')!
    const winston = DEMO_PETS.find((x) => x.name === 'Winston')!
    const topMax = recommendProducts(max, p(max))[0]
    const topWin = recommendProducts(winston, p(winston))[0]
    expect(topMax.id).not.toBe(topWin.id)
  })

  it('filters stage-locked products out of the wrong stage', () => {
    const senior = base({ birthDate: '2014-08-14' })
    const ids = recommendProducts(senior, p(senior)).map((r) => r.id)
    expect(ids).not.toContain('puppy-box')
    const puppy = base({ birthDate: '2026-05-01' })
    expect(recommendProducts(puppy, p(puppy)).map((r) => r.id)).toContain('puppy-box')
  })

  it('is deterministic', () => {
    const profile = base()
    expect(recommendProducts(profile, p(profile))).toEqual(recommendProducts(profile, p(profile)))
  })
})

describe('coverage', () => {
  it('prices every breed inside a plausible band', () => {
    for (const b of ALL_BREEDS) {
      const profile = base({
        species: b.species,
        breedId: b.id,
        weightLb: (b.weight.low + b.weight.high) / 2,
      })
      const c = buildCoverage(profile, p(profile))
      expect(c.monthlyPremium, b.id).toBeGreaterThan(8)
      expect(c.monthlyPremium, b.id).toBeLessThan(200)
      expect(c.totalMonthly, b.id).toBeGreaterThan(c.monthlyPremium)
    }
  })

  it('charges more for an older pet than a younger one, all else equal', () => {
    const young = base({ birthDate: '2024-08-14' })
    const old = base({ birthDate: '2016-08-14' })
    expect(buildCoverage(old, p(old)).monthlyPremium).toBeGreaterThan(
      buildCoverage(young, p(young)).monthlyPremium,
    )
  })

  it('charges more for a shorter-lived breed than a longer-lived one of the same size', () => {
    const frenchie = base({ breedId: 'french-bulldog', weightLb: 24 })
    const jack = base({ breedId: 'jack-russell-terrier', weightLb: 15 })
    expect(buildCoverage(frenchie, p(frenchie)).monthlyPremium).toBeGreaterThan(
      buildCoverage(jack, p(jack)).monthlyPremium,
    )
  })

  it('charges more for a giant breed than a toy breed', () => {
    const dane = base({ breedId: 'great-dane', weightLb: 140 })
    const chi = base({ breedId: 'chihuahua', weightLb: 5 })
    expect(buildCoverage(dane, p(dane)).monthlyPremium).toBeGreaterThan(
      buildCoverage(chi, p(chi)).monthlyPremium,
    )
  })

  it('is deterministic — the same pet always prices the same', () => {
    const profile = base()
    expect(buildCoverage(profile, p(profile))).toEqual(buildCoverage(profile, p(profile)))
  })

  it('shows every pricing factor rather than a single number', () => {
    const profile = base({ conditionIds: ['arthritis'] })
    const c = buildCoverage(profile, p(profile))
    expect(c.breakdown.length).toBeGreaterThanOrEqual(5)
    for (const b of c.breakdown) expect(b.note.length).toBeGreaterThan(10)
  })

  it('marks a declared condition as excluded rather than quietly covering it', () => {
    const profile = base({ conditionIds: ['hip-dysplasia'] })
    const c = buildCoverage(profile, p(profile))
    const hip = c.riskCoverage.find((r) => r.name.toLowerCase().includes('hip'))
    expect(hip?.covered).toBe(false)
    expect(hip?.note).toMatch(/pre-existing/i)
  })

  it('generates rider items matching the current life stage, for every demo pet', () => {
    for (const pet of DEMO_PETS) {
      const proj = p(pet)
      const c = buildCoverage(pet, proj)
      expect(c.riderItems.length, pet.name).toBeGreaterThan(0)
      for (const item of c.riderItems) {
        expect(item.stages, `${pet.name}/${item.id}`).toContain(proj.currentStage.id)
        expect(item.species, `${pet.name}/${item.id}`).toContain(pet.species)
      }
      expect(c.riderTotal, pet.name).toBeGreaterThan(0)
    }
  })

  it('gives demo pets a policy and added pets a quote', () => {
    const max = DEMO_PETS[0]
    expect(buildCoverage(max, p(max)).hasPolicy).toBe(true)
    expect(buildCoverage(max, p(max)).claim).not.toBeNull()
    const mine = base()
    expect(buildCoverage(mine, p(mine)).hasPolicy).toBe(false)
    expect(buildCoverage(mine, p(mine)).claim).toBeNull()
  })

  it('prices the cheaper tier below the standard one', () => {
    const profile = base()
    expect(buildCoverage(profile, p(profile), 'essential').monthlyPremium).toBeLessThan(
      buildCoverage(profile, p(profile), 'complete').monthlyPremium,
    )
  })
})

describe('rewards', () => {
  it('gives a daily brusher a longer dental streak than someone who rarely brushes', () => {
    const daily = base({ dental: 'daily' })
    const rarely = base({ dental: 'rarely' })
    expect(Number(buildRewards(daily, p(daily)).streaks[0].value)).toBeGreaterThan(
      Number(buildRewards(rarely, p(rarely)).streaks[0].value),
    )
  })

  it('is deterministic across calls — simulated, but not random', () => {
    const profile = base()
    expect(buildRewards(profile, p(profile))).toEqual(buildRewards(profile, p(profile)))
  })

  it("recommends redemptions that match the pet's risk profile", () => {
    const profile = base({ conditionIds: ['hip-dysplasia'] })
    const r = buildRewards(profile, p(profile))
    expect(r.redemptions[0].recommended).toBe(true)
  })

  it('marks affordability honestly', () => {
    const profile = base()
    const r = buildRewards(profile, p(profile))
    for (const item of r.redemptions) {
      expect(item.affordable).toBe(r.points >= item.cost)
    }
  })
})

describe('companion', () => {
  it('builds a thread that opens with the owner and closes with the assistant', () => {
    for (const pet of DEMO_PETS) {
      const t = buildCompanion(pet, p(pet))
      expect(t.length).toBeGreaterThanOrEqual(4)
      expect(t[0].from).toBe('user')
      expect(t[t.length - 1].from).toBe('ai')
    }
  })

  it('recalls the declared condition when there is one', () => {
    const max = DEMO_PETS.find((x) => x.name === 'Max')!
    const recall = buildCompanion(max, p(max)).find((m) => m.recall)?.recall
    expect(recall?.text.toLowerCase()).toMatch(/hip/)
  })

  it('says something different for a different pet', () => {
    const max = DEMO_PETS.find((x) => x.name === 'Max')!
    const winston = DEMO_PETS.find((x) => x.name === 'Winston')!
    const a = buildCompanion(max, p(max)).map((m) => m.text).join(' ')
    const b = buildCompanion(winston, p(winston)).map((m) => m.text).join(' ')
    expect(a).not.toBe(b)
  })

  it('offers to route to a vet rather than resolving it alone', () => {
    const max = DEMO_PETS.find((x) => x.name === 'Max')!
    const actions = buildCompanion(max, p(max)).flatMap((m) => m.actions ?? [])
    expect(actions.join(' ').toLowerCase()).toMatch(/vet/)
  })

  it('uses the right pronouns for a female pet', () => {
    const luna = DEMO_PETS.find((x) => x.name === 'Luna')!
    const text = buildCompanion(luna, p(luna)).map((m) => m.text + (m.recall?.text ?? '')).join(' ')
    expect(text).not.toMatch(/\bhis\b/)
  })

  it('builds a thread for every breed without throwing', () => {
    for (const b of ALL_BREEDS) {
      const profile = base({
        species: b.species,
        breedId: b.id,
        weightLb: (b.weight.low + b.weight.high) / 2,
      })
      expect(() => buildCompanion(profile, p(profile)), b.id).not.toThrow()
    }
  })
})

describe('home', () => {
  it('produces a nudge and a score for every demo pet', () => {
    for (const pet of DEMO_PETS) {
      const h = buildHome(pet, p(pet))
      expect(h.nudge.title.length).toBeGreaterThan(8)
      expect(h.score?.value).toBeGreaterThan(0)
      expect(h.stepsTrend.length).toBe(7)
      expect(h.steps).toBeGreaterThan(0)
    }
  })

  it("tells Max's activity story specifically", () => {
    const max = DEMO_PETS.find((x) => x.name === 'Max')!
    const h = buildHome(max, p(max))
    expect(h.trendDown).toBe(true)
    expect(h.nudge.title.toLowerCase()).toMatch(/activity/)
    expect(h.nudge.body.toLowerCase()).toMatch(/hip/)
  })

  it('points at the biggest lever when nothing is trending down', () => {
    const profile = base({ dental: 'rarely', activity: 'high' })
    const h = buildHome(profile, p(profile))
    expect(h.nudge.eyebrow).toBe('Biggest lever')
    expect(h.nudge.title.toLowerCase()).toMatch(/dental/)
  })

  it('is deterministic', () => {
    const profile = base()
    expect(buildHome(profile, p(profile))).toEqual(buildHome(profile, p(profile)))
  })
})

describe('defensive against malformed stored pets', () => {
  // App.tsx validates localStorage before anything reaches the engine, but these
  // guards are the second layer — a demo must not white-screen on bad state.
  it('survives a pet with no conditionIds array', () => {
    const broken = { ...base(), conditionIds: undefined } as unknown as PetProfile
    expect(() => buildCoverage(broken, p(base()))).not.toThrow()
    expect(buildCoverage(broken, p(base())).monthlyPremium).toBeGreaterThan(0)
  })

  it('returns an empty companion thread rather than throwing on no risk cards', () => {
    const proj = { ...p(base()), riskCards: [] }
    expect(() => buildCompanion(base(), proj)).not.toThrow()
    expect(buildCompanion(base(), proj)).toEqual([])
  })

  it('still throws loudly on an unknown breed, so the boundary can catch it', () => {
    expect(() => p({ ...base(), breedId: 'not-a-breed' })).toThrow(/Unknown breed/)
  })
})

// UAT run 1, D2–D3: a default is not an answer.
describe('defaults are not answers', () => {
  const untold = base({ dental: undefined, activity: undefined, neutered: undefined, diet: undefined, weightLb: 0 })

  it('each lever knows whether the owner told us', () => {
    const told = Object.fromEntries(p(base()).levers.map((l) => [l.id, l.told]))
    expect(told).toEqual({ weight: true, dental: true, activity: true })
    expect(p(untold).levers.every((l) => !l.told)).toBe(true)
  })

  it('an unanswered band says so, rather than naming the default', () => {
    const bands = clovaraScore(untold, p(untold)).bands
    for (const id of ['dental', 'activity', 'neuter']) {
      expect(bands.find((b) => b.id === id)?.detail, id).toMatch(/Not asked yet/)
    }
    // "Intact" was said of a dog nobody had asked about.
    expect(bands.find((b) => b.id === 'neuter')?.detail).not.toMatch(/Intact/)
  })

  it('the biggest lever is only ever something the owner told us', () => {
    expect(clovaraScore(untold, p(untold)).biggestGap).toBeNull()
    const rarely = base({ dental: 'rarely' })
    expect(clovaraScore(rarely, p(rarely)).biggestGap?.id, 'control').toBe('dental')
  })

  it('and never teeth for a puppy', () => {
    const pup = base({ birthDate: '2026-06-12', dental: 'rarely' })
    expect(p(pup).currentStage.id).toBe('puppy')
    expect(clovaraScore(pup, p(pup)).biggestGap?.id).not.toBe('dental')
  })
})
