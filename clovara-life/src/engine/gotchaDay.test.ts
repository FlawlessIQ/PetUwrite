import { describe, expect, it } from 'vitest'
import { gotchaState, GOTCHA_WINDOW_DAYS } from './gotchaDay'
import type { PetProfile } from '../data/types'

const pet = (over: Partial<PetProfile> = {}): PetProfile => ({
  id: 'p',
  name: 'Scout',
  species: 'dog',
  breedId: 'labrador-retriever',
  birthDate: '2017-04-02',
  sex: 'female',
  weightLb: 0,
  conditionIds: [],
  ...over,
})

const at = (iso: string) => new Date(`${iso}T12:00:00Z`)

describe('Gotcha Day', () => {
  it('is on for the anniversary of coming home', () => {
    const s = gotchaState(pet({ knownSince: '2023-09-23T10:00:00Z' }), at('2026-09-23'))
    expect(s.active).toBe(true)
    expect(s.years).toBe(3)
    expect(s.daysSince).toBe(0)
  })

  it('lingers for a week, because people miss the day', () => {
    const p = pet({ knownSince: '2023-09-23T10:00:00Z' })
    expect(gotchaState(p, at('2026-09-27')).active).toBe(true)
    expect(gotchaState(p, at('2026-09-29')).active).toBe(true)
    expect(gotchaState(p, at('2026-10-01')).active).toBe(false)
  })

  it('is off on an ordinary day', () => {
    expect(gotchaState(pet({ knownSince: '2023-03-01T10:00:00Z' }), at('2026-09-23')).active).toBe(
      false,
    )
  })

  it('does not celebrate the day they arrived', () => {
    // Homecoming day itself is not an anniversary, and a card saying "0 years
    // home" would be a strange thing to be handed.
    const s = gotchaState(pet({ knownSince: '2026-09-23T08:00:00Z' }), at('2026-09-23'))
    expect(s.active).toBe(false)
    expect(s.years).toBe(0)
  })

  it('reaches the first one at a year, not before', () => {
    const p = pet({ knownSince: '2025-09-23T10:00:00Z' })
    expect(gotchaState(p, at('2026-09-22')).active).toBe(false)
    expect(gotchaState(p, at('2026-09-23')).years).toBe(1)
    expect(gotchaState(p, at('2026-09-23')).active).toBe(true)
  })

  it('handles an anniversary that has not come round yet this year', () => {
    // Asked in January about a pet who came home in September.
    const s = gotchaState(pet({ knownSince: '2022-09-23T10:00:00Z' }), at('2026-01-15'))
    expect(s.years).toBe(3)
    expect(s.active).toBe(false)
  })

  it('is off when we do not know when they came home', () => {
    expect(gotchaState(pet(), at('2026-09-23')).active).toBe(false)
    expect(gotchaState(pet({ knownSince: 'whenever' }), at('2026-09-23')).active).toBe(false)
  })

  it('uses the homecoming, never the birthday', () => {
    // A rescue born in 2017 and homed in 2024 has a Gotcha Day in 2025, not
    // eight of them already behind him.
    const s = gotchaState(
      pet({ birthDate: '2017-04-02', knownSince: '2024-09-23T10:00:00Z' }),
      at('2026-09-23'),
    )
    expect(s.years).toBe(2)
  })

  it('keeps the window short enough to still mean something', () => {
    expect(GOTCHA_WINDOW_DAYS).toBeLessThanOrEqual(14)
  })
})
