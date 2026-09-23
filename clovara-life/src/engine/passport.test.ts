import { describe, expect, it } from 'vitest'
import { passportState, windowCopy, WEEKS_PER_YEAR } from './passport'
import { SOCIAL_STAMPS, WINDOW_WEEKS, stampsFor, PASSPORT_PRINCIPLE } from '../data/socialization'
import type { PetProfile } from '../data/types'

const NOW = new Date('2026-09-23T12:00:00Z')
const weeksOld = (w: number) =>
  new Date(NOW.getTime() - (w / WEEKS_PER_YEAR) * 365.25 * 86_400_000).toISOString().slice(0, 10)

const pet = (over: Partial<PetProfile> = {}): PetProfile => ({
  id: 'p',
  name: 'Scout',
  species: 'dog',
  breedId: 'labrador-retriever',
  birthDate: weeksOld(9),
  sex: 'female',
  weightLb: 0,
  conditionIds: [],
  ...over,
})

describe('the content', () => {
  it('is about a hundred stamps for each species, as SPEC asks', () => {
    expect(stampsFor('dog').length).toBeGreaterThanOrEqual(90)
    expect(stampsFor('cat').length).toBeGreaterThanOrEqual(90)
  })

  it('has no duplicate ids, which would double-count somebody', () => {
    const ids = SOCIAL_STAMPS.map((x) => x.id)
    expect(new Set(ids).size).toBe(ids.length)
  })

  it('is qualitative only — never a count, a duration or a protocol', () => {
    // SPEC §6.3: "qualitative copy only". "Expose to five strangers daily" is a
    // training programme written by someone who has not met the dog.
    for (const st of SOCIAL_STAMPS) {
      expect(st.label, st.id).not.toMatch(
        /\b(\d+\s*(times|minutes|seconds|daily|a day|per day)|repeat|sessions?)\b/i,
      )
    }
  })

  it('never tells somebody when a puppy may meet strange dogs', () => {
    // That depends on vaccination and on where they live, and it is a question
    // for their own vet. Invariant 4.
    const blob = SOCIAL_STAMPS.map((x) => x.label).join(' ')
    expect(blob).not.toMatch(/after (the|their) (second|final|last) (jab|vaccination)/i)
    expect(stampsFor('dog').find((x) => x.id === 'a-adult-dog')!.label).toMatch(/vaccinated/i)
  })

  it('says a frightened animal has not been socialised', () => {
    // The whole failure mode of a gamified checklist is somebody chasing stamps
    // past the point where the animal is coping.
    expect(PASSPORT_PRINCIPLE).toMatch(/frightened/i)
    expect(PASSPORT_PRINCIPLE).toMatch(/does not count/i)
  })

  it('gives dogs and cats each their own species-specific stamps', () => {
    expect(stampsFor('dog').some((x) => x.id === 'e-crate')).toBe(true)
    expect(stampsFor('cat').some((x) => x.id === 'e-crate')).toBe(false)
    expect(stampsFor('cat').some((x) => x.id === 'e-tray-change')).toBe(true)
    expect(stampsFor('dog').some((x) => x.id === 'e-tray-change')).toBe(false)
  })
})

describe('the window', () => {
  it('is open for a nine-week-old puppy', () => {
    const s = passportState(pet(), NOW)
    expect(s.window).toBe('open')
    expect(s.visible).toBe(true)
    expect(s.weeksLeft).toBeGreaterThan(0)
  })

  it('is already closing for a nine-week-old KITTEN', () => {
    // The thing most products get wrong. A cat's sensitive period is roughly
    // 2–7 weeks and is over before most kittens are adopted.
    const s = passportState(pet({ species: 'cat', breedId: 'domestic-shorthair' }), NOW)
    expect(s.window).toBe('closing')
    expect(s.weeksLeft).toBe(0)
  })

  it('hides itself once the pet is well past it', () => {
    expect(passportState(pet({ birthDate: weeksOld(40) }), NOW).visible).toBe(false)
  })

  it('counts down the weeks left honestly', () => {
    const s = passportState(pet({ birthDate: weeksOld(12) }), NOW)
    expect(s.weeksLeft).toBeLessThanOrEqual(WINDOW_WEEKS.dog.closes - 12 + 1)
    expect(s.weeksLeft).toBeGreaterThan(0)
  })
})

describe('progress', () => {
  it('counts only stamps that still exist', () => {
    // A stamp retired from the content must not keep counting, or the passport
    // slowly fills itself without anybody doing anything.
    const s = passportState(pet({ socialStamps: ['p-child', 'a-stamp-we-deleted'] }), NOW)
    expect(s.collected).toEqual(['p-child'])
  })

  it('is zero for a pet with none, not NaN', () => {
    expect(passportState(pet(), NOW).progress).toBe(0)
  })

  it('reaches one when everything is collected', () => {
    const all = stampsFor('dog').map((x) => x.id)
    expect(passportState(pet({ socialStamps: all }), NOW).progress).toBe(1)
  })

  it('never credits a dog for a cat-only stamp', () => {
    const s = passportState(pet({ socialStamps: ['e-tray-change'] }), NOW)
    expect(s.byGroup.reduce((n, g) => n + g.done, 0)).toBe(0)
  })

  it('groups the pages so no group is empty', () => {
    const s = passportState(pet(), NOW)
    expect(s.byGroup.length).toBeGreaterThan(5)
    expect(s.byGroup.every((g) => g.total > 0)).toBe(true)
  })
})

describe('what it says about the window', () => {
  it('tells a puppy owner how long the easy part lasts', () => {
    const p = pet()
    const c = windowCopy(p, passportState(p, NOW))
    expect(c.title).toMatch(/week/)
    expect(c.body).toMatch(/frightened/)
  })

  it('tells a kitten owner the early part was not theirs to do', () => {
    // Implying they missed something they never had the chance to do would be
    // both wrong and unkind.
    const p = pet({ species: 'cat', breedId: 'domestic-shorthair', name: 'Pip' })
    const c = windowCopy(p, passportState(p, NOW))
    expect(c.body).toMatch(/before most kittens come home/i)
    expect(c.body).toMatch(/not to you/i)
    expect(c.body).toMatch(/still works/i)
    expect(c.title).not.toMatch(/hurry|quick|last chance/i)
  })

  it('never tells anybody they have failed or run out', () => {
    for (const species of ['dog', 'cat'] as const) {
      for (const weeks of [4, 9, 15]) {
        const p = pet({
          species,
          breedId: species === 'cat' ? 'domestic-shorthair' : 'labrador-retriever',
          birthDate: weeksOld(weeks),
        })
        const c = windowCopy(p, passportState(p, NOW))
        expect(`${c.title} ${c.body}`, `${species} @ ${weeks}w`).not.toMatch(
          /too late|missed your chance|failed|should have/i,
        )
      }
    }
  })
})
