import { describe, expect, it } from 'vitest'
import { isRemembered, MUST_GO_QUIET, REMEMBER_BODY, REMEMBER_PROMPT, STAYS } from './remember'
import { reviewDue } from './review'
import { gotchaState } from './gotchaDay'
import { vaccineState } from './vaccines'
import { passportState } from './passport'
import { buildCompanion, buildCoverage, buildHome, buildRewards, recommendProducts } from './platform'
import { planAccuracy } from './accuracy'
import { asksFor } from '../data/askRegistry'
import { project } from './project'
import type { PetProfile } from '../data/types'

const NOW = new Date('2026-09-24T12:00:00Z')
const daysAgo = (n: number) => new Date(NOW.getTime() - n * 86_400_000).toISOString()

/** A pet in the state where everything would otherwise be shouting. */
const alive = (over: Partial<PetProfile> = {}): PetProfile => ({
  id: 'p',
  name: 'Scout',
  species: 'dog',
  breedId: 'labrador-retriever',
  birthDate: '2018-09-24',
  sex: 'female',
  weightLb: 0,
  conditionIds: [],
  // Review overdue, Gotcha Day today, vaccinations unrecorded, nothing answered.
  knownSince: daysAgo(1100),
  ...over,
})
const died = (over: Partial<PetProfile> = {}) => alive({ diedOn: daysAgo(20), ...over })
const proj = (p: PetProfile) => project(p, { now: NOW })

describe('the flag itself', () => {
  it('is off until an owner tells us', () => {
    expect(isRemembered(alive())).toBe(false)
    expect(isRemembered(died())).toBe(true)
  })

  it('ignores a date we cannot read rather than half-silencing', () => {
    expect(isRemembered({ diedOn: 'sometime' })).toBe(false)
  })
})

describe('EVERY surface that would otherwise carry on', () => {
  // The list is exported so this test can enumerate it. Adding a surface means
  // adding it here and proving it is silent — the sixteenth surface nobody
  // remembered is the one that sends the email.
  it('covers everything named in MUST_GO_QUIET', () => {
    expect(MUST_GO_QUIET.length).toBeGreaterThanOrEqual(10)
  })

  it('the annual re-projection does not ask how the year went', () => {
    expect(reviewDue(alive(), NOW), 'control: should be due').toBe(true)
    expect(reviewDue(died(), NOW)).toBe(false)
  })

  it('no anniversary card arrives', () => {
    const anniversary = { knownSince: new Date(Date.UTC(2022, 8, 24)).toISOString() }
    expect(gotchaState(alive(anniversary), NOW).active, 'control').toBe(true)
    expect(gotchaState(died(anniversary), NOW).active).toBe(false)
  })

  it('no vaccination is ever due again', () => {
    const young = { birthDate: '2026-06-24' }
    expect(vaccineState(alive(young), NOW).visible, 'control').toBe(true)
    expect(vaccineState(died(young), NOW).visible).toBe(false)
  })

  it('the socialization passport disappears', () => {
    const pup = { birthDate: '2026-08-01' }
    expect(passportState(alive(pup), NOW).visible, 'control').toBe(true)
    expect(passportState(died(pup), NOW).visible).toBe(false)
  })

  it('nothing is recommended to buy', () => {
    expect(recommendProducts(alive(), proj(alive())).length, 'control').toBeGreaterThan(0)
    expect(recommendProducts(died(), proj(died()))).toHaveLength(0)
  })

  it('no question is asked on any surface', () => {
    for (const trigger of ['life', 'shop', 'lost-pet-card', 'attach', 'sitter-mode', 'trial-end'] as const) {
      expect(asksFor(trigger, died()), trigger).toHaveLength(0)
    }
    expect(asksFor('life', alive()).length, 'control').toBeGreaterThan(0)
  })

  // UAT K1–K2: listed here from the start, and still shown on Home after a
  // death — "72% sharp — add neutered or spayed to reach 81%". Enumerating the
  // list is not the same as proving each item.
  it('the plan stops asking to be sharpened', () => {
    expect(planAccuracy(alive()).showOnHome, 'control').toBe(true)
    expect(planAccuracy(alive()).nextBest, 'control').not.toBeNull()
    const a = planAccuracy(died())
    expect(a.showOnHome).toBe(false)
    expect(a.nextBest).toBeNull()
    expect(a.scoreWithNextBest).toBe(a.score)
  })

  it('Home stops grading them, and nothing is coming up', () => {
    // A puppy's stage has a wellness-rider item, so the control has one.
    const pup = { birthDate: '2026-06-24' }
    expect(buildHome(alive(pup), proj(alive(pup))).score, 'control').not.toBeNull()
    expect(buildHome(alive(pup), proj(alive(pup))).comingUp, 'control').not.toBeNull()
    const home = buildHome(died(pup), proj(died(pup)))
    expect(home.score).toBeNull()
    expect(home.comingUp).toBeNull()
  })

  // UAT run 1, D19: Rewards, Care and Coverage kept going, and Life still
  // forecast healthy years, a day after.
  it('nothing is counted any more', () => {
    expect(buildRewards(alive(), proj(alive())), 'control').not.toBeNull()
    expect(buildRewards(died(), proj(died()))).toBeNull()
  })

  it('the companion has nothing to say', () => {
    expect(buildCompanion(alive(), proj(alive())).length, 'control').toBeGreaterThan(0)
    expect(buildCompanion(died(), proj(died()))).toHaveLength(0)
  })

  it('no cover is priced', () => {
    expect(buildCoverage(alive(), proj(alive())), 'control').not.toBeNull()
    expect(buildCoverage(died(), proj(died()))).toBeNull()
  })

  it('their age stops at the day they died', () => {
    // Born 2018-09-24, died twenty days before NOW (2026-09-24): about 8, and
    // still about 8 when somebody looks in 2030.
    const later = new Date('2030-01-01T00:00:00Z')
    expect(project(alive(), { now: later }).ageYears, 'control').toBeGreaterThan(11)
    expect(project(died(), { now: later }).ageYears).toBeLessThanOrEqual(8)
    expect(project(died(), { now: later }).ageYears).toBe(project(died(), { now: NOW }).ageYears)
  })

  it('the home nudge stops talking about them in the present', () => {
    const home = buildHome(died(), proj(died()))
    expect(home.nudge.title).toMatch(/record is still here/i)
    expect(home.nudge.body).toMatch(/Nothing else is needed from you/i)
  })
})

describe('the four failures that ship in real products', () => {
  const p = died()
  const home = buildHome(p, proj(p))
  const blob = [
    home.nudge.eyebrow,
    home.nudge.title,
    home.nudge.body,
    ...asksFor('life', p).map((a) => a.question),
    ...recommendProducts(p, proj(p)).map((r) => `${r.name} ${r.why}`),
  ].join(' ')

  it('never asks how they are doing', () => {
    expect(blob).not.toMatch(/how (is|are) (she|he|they|Scout)|doing well|on track|activity/i)
  })

  it('never reminds about anything due', () => {
    expect(blob).not.toMatch(/\b(due|overdue|reminder|book|schedule|renew)\b/i)
  })

  it('never recommends buying anything', () => {
    expect(blob).not.toMatch(/\b(buy|shop|order|recommend|save|offer|deal)\b/i)
  })

  it('never suggests another animal', () => {
    // The one that says most about how a product understood the relationship.
    expect(blob).not.toMatch(/\b(another pet|new pet|second pet|adopt|puppy|kitten)\b/i)
  })

  it('and asks nothing at all', () => {
    expect(REMEMBER_PROMPT).toMatch(/nothing else is needed/i)
    expect(REMEMBER_PROMPT).not.toMatch(/\?|rate|review|feedback|tell us/i)
  })
})

describe('what stays', () => {
  it('nothing is deleted, and it says so', () => {
    expect(REMEMBER_BODY('Scout')).toMatch(/Nothing has been deleted, and nothing will be/i)
    expect(REMEMBER_BODY('Scout')).toMatch(/Whenever you want it, it is here/i)
  })

  it('the record, photographs and summary all remain reachable', () => {
    expect(STAYS.join(' ')).toMatch(/record/i)
    expect(STAYS.join(' ')).toMatch(/photograph/i)
    expect(STAYS.join(' ')).toMatch(/summary/i)
  })

  it('the projection engine still runs, so the record can be read', () => {
    // Taking the record away would be the fifth failure.
    expect(() => proj(died())).not.toThrow()
  })
})
