import { describe, expect, it } from 'vitest'
import { seniorState, SENIOR_STAGES } from './senior'
import {
  ADAPTATIONS,
  MENTION_NOTE,
  NO_SCALE_NOTE,
  SENIOR_OPENING,
  WORTH_MENTIONING,
} from '../data/senior'
import { project } from './project'
import type { PetProfile } from '../data/types'

const NOW = new Date('2026-09-24T12:00:00Z')
const pet = (over: Partial<PetProfile> = {}): PetProfile => ({
  id: 'p',
  name: 'Scout',
  species: 'dog',
  breedId: 'labrador-retriever',
  birthDate: '2014-04-02', // ~12
  sex: 'female',
  weightLb: 68,
  conditionIds: [],
  ...over,
})
const state = (p: PetProfile) => seniorState(p, project(p, { now: NOW }))

describe('when it appears', () => {
  it('is there for an older animal', () => {
    const s = state(pet())
    expect(s.visible).toBe(true)
    expect(SENIOR_STAGES.join(' ')).toMatch(/senior/)
  })

  it('is absent for a young one', () => {
    expect(state(pet({ birthDate: '2024-04-02' })).visible).toBe(false)
  })

  it('is absent once a pet has died', () => {
    expect(state(pet({ diedOn: '2026-09-01' })).visible).toBe(false)
  })
})

describe('what it must never do', () => {
  it('NEVER estimates remaining time', () => {
    // The projection is a planning range from breed medians. In front of the
    // owner of a thirteen-year-old it reads as a countdown.
    const s = state(pet())
    const blob = [s.stageSummary, ...s.careActions, ...s.adaptations.map((a) => `${a.what} ${a.why}`), ...s.worthMentioning].join(' ')
    expect(blob).not.toMatch(
      /\b(years left|time left|remaining|how long|final|last years|end of life|not long)\b/i,
    )
    expect(JSON.stringify(s)).not.toMatch(/healthyYears|\d+\.\d\s*–\s*\d+\.\d/)
  })

  it('never frames ageing as decline to be fought', () => {
    const blob = [SENIOR_OPENING, ...ADAPTATIONS.map((a) => `${a.what} ${a.why}`)].join(' ')
    expect(blob).not.toMatch(/\b(fight|battle|slow (it|the ageing)|combat|reverse|defy|still young)\b/i)
    expect(SENIOR_OPENING).toMatch(/nothing here is about slowing anything down/i)
  })

  it('never promises a longer life (VISION vocabulary)', () => {
    const blob = ADAPTATIONS.map((a) => a.why).join(' ')
    expect(blob).not.toMatch(/live longer|longer life|extra years|add years|more years/i)
  })

  it('carries NO quality-of-life scale, and says why', () => {
    // Inventing a score for how good an animal's life is would be the worst
    // thing in this codebase. Validated scales exist and belong with a vet.
    const s = state(pet())
    // Word-bounded: "pressure points" in the bedding copy is not a score.
    expect(JSON.stringify(s)).not.toMatch(
      /\b(score|scored|scoring|rating|rate it|out of (five|six|ten|\d)|quality.of.life scale)\b/i,
    )
    expect(NO_SCALE_NOTE).toMatch(/we do not score/i)
    expect(NO_SCALE_NOTE).toMatch(/belong with a vet/i)
    expect(NO_SCALE_NOTE).toMatch(/six tick boxes/i)
  })

  it('never says what an observation might mean', () => {
    // Naming what each might be would be diagnosing, and would turn the list
    // into the scale that is deliberately absent.
    const blob = Object.values(WORTH_MENTIONING).flat().join(' ')
    expect(blob).not.toMatch(
      /\b(sign of|indicates|suggests|could be|may be|arthritis|kidney|cognitive|dementia|dysfunction)\b/i,
    )
    expect(MENTION_NOTE).toMatch(/none of these mean anything on their own/i)
    expect(MENTION_NOTE).toMatch(/not going to tell you what they might be/i)
  })
})

describe('what it assembles', () => {
  it('uses the stage the engine already computed', () => {
    const s = state(pet())
    expect(s.stageLabel.length).toBeGreaterThan(2)
    expect(s.stageSummary.length).toBeGreaterThan(10)
  })

  it('lists only risk windows that are actually open', () => {
    // Listing everything a breed might ever face turns a page about making the
    // house easier into a list of things to dread.
    const s = state(pet())
    expect(s.openNow.every((c) => c.mode === 'active' || c.mode === 'manage')).toBe(true)
  })

  it('gives a dog ramps and a cat a litter tray', () => {
    const dog = state(pet()).adaptations.map((a) => a.id)
    const cat = state(pet({ species: 'cat', breedId: 'domestic-shorthair' })).adaptations.map((a) => a.id)
    expect(dog).toContain('ramp')
    expect(dog).not.toContain('tray')
    expect(cat).toContain('tray')
    expect(cat).not.toContain('ramp')
  })

  it('shares the things that help either species', () => {
    for (const id of ['floors', 'bed', 'water', 'night', 'nails']) {
      expect(ADAPTATIONS.find((a) => a.id === id)!.species.length, id).toBe(2)
    }
  })

  it('gives every adaptation a reason about the animal, not about us', () => {
    for (const a of ADAPTATIONS) {
      expect(a.why.length, a.id).toBeGreaterThan(40)
      // \bour\b — "behaviour" and "your" both contain it.
      expect(a.why, a.id).not.toMatch(/\bour\b|we recommend|Clovara/i)
    }
  })

  it('has species-specific things to mention, not one shared list', () => {
    expect(WORTH_MENTIONING.cat.join(' ')).toMatch(/tray|grooming|jumping/i)
    expect(WORTH_MENTIONING.dog.join(' ')).toMatch(/stairs|walk/i)
    expect(WORTH_MENTIONING.cat).not.toEqual(WORTH_MENTIONING.dog)
  })
})
