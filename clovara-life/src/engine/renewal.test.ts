import { describe, expect, it } from 'vitest'
import { explainRenewal, RENEWAL_EXPLAINED_ENABLED } from './renewal'
import type { PetProfile } from '../data/types'

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

const explain = (over: Partial<Parameters<typeof explainRenewal>[2]> = {}) =>
  explainRenewal(
    pet(),
    { monthly: 32.4, ageYears: 5 },
    { monthly: 35.1, ageYears: 6, claimsLastYear: 0, ...over },
  )

describe('the flag', () => {
  it('is off until real policies exist', () => {
    // SPEC §6.8: "template exists behind a flag; activates with real policies".
    // A renewal screen driven by illustrative numbers is a screen about nothing.
    expect(RENEWAL_EXPLAINED_ENABLED).toBe(false)
  })
})

describe('what moves the price', () => {
  it('names age, which is the one nobody can do anything about', () => {
    const r = explain()
    const age = r.lines.find((l) => l.id === 'age')!
    expect(age.label).toMatch(/year older/)
    expect(age.delta).toBeGreaterThan(0)
  })

  it('treats claims experience as a filed factor, not a score for caring', () => {
    // The distinction the whole screen turns on. Whether a policy was claimed
    // on is a rating factor everywhere insurance is sold. How somebody looked
    // after their pet is not, and must never become one.
    const clean = explain({ claimsLastYear: 0 })
    const claimed = explain({ claimsLastYear: 2 })
    for (const r of [clean, claimed]) {
      const claims = r.lines.find((l) => l.id === 'claims')!
      expect(claims.because).toMatch(/filed/i)
      expect(claims.because).toMatch(/not (a score for how you looked after them|how you cared for them)/i)
    }
    expect(clean.lines.find((l) => l.id === 'claims')!.delta).toBe(0)
  })

  it('separates a filed rate change from anything about this pet', () => {
    const r = explain({ filedRateChange: 1.2 })
    const filed = r.lines.find((l) => l.id === 'filed')!
    expect(filed.because).toMatch(/nothing to do with your pet/i)
  })

  it('does not invent an age line when they have not had a birthday', () => {
    const r = explainRenewal(
      pet(),
      { monthly: 32, ageYears: 6 },
      { monthly: 32, ageYears: 6.5, claimsLastYear: 0 },
    )
    expect(r.lines.some((l) => l.id === 'age')).toBe(false)
    expect(r.unchanged).toBe(true)
  })
})

describe('what must never move the price', () => {
  it('NEVER credits care, behaviour, streaks or a tracker', () => {
    // The Data Covenant promises premiums do not move on this data — "not up,
    // and not down as a reward for behaving". A renewal screen that credited
    // somebody's dental streak would break the covenant in the direction people
    // find pleasant, which is the direction a product like this drifts.
    for (const claims of [0, 3]) {
      const r = explain({ claimsLastYear: claims })
      const blob = r.lines.map((l) => `${l.label} ${l.because}`).join(' ')
      expect(blob).not.toMatch(
        /\b(streak|tracker|steps|dental routine|your care|good behaviour|reward|discount for|because you)\b/i,
      )
    }
  })

  it('names what is not a factor, on the page, rather than leaving it inferred', () => {
    const r = explain()
    const blob = r.notFactors.join(' ').toLowerCase()
    for (const thing of ['companion', 'tracker', 'streak', 'score']) {
      expect(blob, thing).toContain(thing)
    }
  })

  it('includes "whether you opened the app at all", which is the creepy one', () => {
    expect(explain().notFactors.join(' ')).toMatch(/opened the app/i)
  })
})
