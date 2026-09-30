import { describe, expect, it } from 'vitest'
import { momentsDue } from './moments'
import type { PetProfile } from '../data/types'

const NOW = new Date('2026-09-30T08:00:00Z')
const ago = (days: number) => new Date(NOW.getTime() - days * 86_400_000).toISOString()
const pet = (over: Partial<PetProfile> = {}): PetProfile => ({
  id: 'bruno', name: 'Bruno', species: 'dog', breedId: 'labrador-retriever', sex: 'male',
  weightLb: 0, conditionIds: [], birthDate: ago(63).slice(0, 10), knownSince: ago(30), ...over,
})
const kinds = (p: PetProfile, now = NOW) => momentsDue(p, now).map((m) => m.kind)

describe('what is worth an email today', () => {
  it('the morning after a puppy comes home: the first night, once', () => {
    const home = pet({ knownSince: new Date(NOW.getTime() - 20 * 3_600_000).toISOString() })
    const m = momentsDue(home, NOW).find((x) => x.kind === 'first-nights')
    expect(m?.key).toBe('first-nights')
    expect(m?.lines.join(' ')).toMatch(/Call a vet now, at any hour/)
    // Not in the first hours, and not after the third day.
    expect(kinds(pet({ knownSince: new Date(NOW.getTime() - 3 * 3_600_000).toISOString() }))).not.toContain('first-nights')
    expect(kinds(pet({ knownSince: ago(3) }))).not.toContain('first-nights')
  })

  it('a vaccination window: in the days after it opens, and not once recorded', () => {
    // DHP second dose usually opens around ten weeks.
    const ten = pet({ birthDate: ago(10 * 7 + 1).slice(0, 10) })
    const due = momentsDue(ten, NOW).filter((m) => m.kind === 'vaccine')
    expect(due.length).toBeGreaterThan(0)
    expect(due[0].subject).toMatch(/usually given/)
    expect(due[0].lines.join(' ')).toMatch(/Your vet sets the schedule/)
    const recorded = pet({ birthDate: ten.birthDate, vaccineRecords: due.map((m) => ({ doseId: m.key.replace('vaccine:', ''), givenOn: ago(1) })) })
    expect(kinds(recorded)).not.toContain('vaccine')
  })

  it('two weeks of the easy part left, and not at three', () => {
    expect(kinds(pet({ birthDate: ago(12 * 7 + 3).slice(0, 10) }))).toContain('passport')
    expect(kinds(pet({ birthDate: ago(10 * 7 + 3).slice(0, 10) }))).not.toContain('passport')
  })

  it('the yearly check, keyed by year so it goes once a year', () => {
    const adult = pet({ birthDate: '2022-03-01', knownSince: '2022-05-10T12:00:00Z' })
    const m = momentsDue(adult, NOW).find((x) => x.kind === 'review')
    expect(m?.key).toBe('review:2026')
  })

  it('Gotcha Day on the day', () => {
    const m = momentsDue(pet({ birthDate: '2021-01-01', knownSince: '2023-09-30T08:00:00Z', lastReviewedAt: ago(20) }), NOW).find((x) => x.kind === 'gotcha')
    expect(m?.subject).toBe("Bruno's Gotcha Day — 3 years home")
    expect(m?.key).toBe('gotcha:3')
  })

  it('nothing for a demo pet or a pet who has died', () => {
    const busy = { birthDate: ago(10 * 7 + 1).slice(0, 10), knownSince: new Date(NOW.getTime() - 20 * 3_600_000).toISOString() }
    expect(momentsDue(pet(busy), NOW).length, 'control').toBeGreaterThan(0)
    expect(momentsDue(pet({ ...busy, demo: true }), NOW)).toEqual([])
    expect(momentsDue(pet({ ...busy, diedOn: ago(1).slice(0, 10) }), NOW)).toEqual([])
  })

  it('never diagnoses, never sells', () => {
    const all = [
      pet({ birthDate: ago(10 * 7 + 1).slice(0, 10), knownSince: new Date(NOW.getTime() - 20 * 3_600_000).toISOString() }),
      pet({ birthDate: ago(12 * 7 + 3).slice(0, 10) }),
      pet({ birthDate: '2022-03-01', knownSince: '2022-05-10T12:00:00Z' }),
    ].flatMap((p) => momentsDue(p, NOW)).map((m) => m.subject + ' ' + m.lines.join(' ')).join(' ')
    // "Anything diagnosed?" is asking what a VET found, which is allowed; these
    // are the shapes of us deciding what something is, or selling.
    expect(all).not.toMatch(/sounds like|could be|is likely|probably|it is (a|an) |\$\d|buy|shop|discount|offer/i)
  })
})
