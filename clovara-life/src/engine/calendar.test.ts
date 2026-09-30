import { describe, expect, it } from 'vitest'
import { calendarEvents, toIcs } from './calendar'
import type { PetProfile } from '../data/types'

const NOW = new Date('2026-09-30T12:00:00Z')
const pet = (over: Partial<PetProfile> = {}): PetProfile => ({
  id: 'bruno', name: 'Bruno', species: 'dog', breedId: 'labrador-retriever', sex: 'male',
  weightLb: 0, conditionIds: [], birthDate: '2026-07-29', knownSince: '2026-09-29T12:00:00Z', ...over,
})

describe('what goes in the calendar', () => {
  it('a new puppy gets the vaccinations still ahead, the socialisation window, and Gotcha Day', () => {
    const ev = calendarEvents(pet(), NOW)
    const ids = ev.map((e) => e.uid)
    expect(ids.some((u) => u.startsWith('vaccine-'))).toBe(true)
    expect(ids).toContain('passport-two-weeks')
    expect(ids).toContain('passport-closes')
    expect(ids).toContain('gotcha-day')
    expect(ev.find((e) => e.uid === 'gotcha-day')?.date).toBe('2027-09-29')
  })

  it('never lists anything in the past, and is in date order', () => {
    const ev = calendarEvents(pet(), NOW)
    for (const e of ev) expect(e.date > '2026-09-30').toBe(true)
    expect([...ev].sort((a, b) => a.date.localeCompare(b.date))).toEqual(ev)
  })

  it('drops a dose once it is recorded', () => {
    const before = calendarEvents(pet(), NOW).filter((e) => e.uid.startsWith('vaccine-'))
    const first = before[0].uid.replace('vaccine-', '')
    const after = calendarEvents(pet({ vaccineRecords: [{ doseId: first, givenOn: '2026-09-30' }] }), NOW)
    expect(after.map((e) => e.uid)).not.toContain(`vaccine-${first}`)
  })

  it('an adult gets the yearly check and Gotcha Day, and no puppy dates', () => {
    const adult = pet({ birthDate: '2022-03-01', knownSince: '2022-05-10T12:00:00Z', lastReviewedAt: '2026-06-01T12:00:00Z' })
    const ids = calendarEvents(adult, NOW).map((e) => e.uid)
    expect(ids).toContain('annual-review')
    expect(ids).toContain('gotcha-day')
    expect(ids.filter((u) => u.startsWith('passport') || u.startsWith('vaccine'))).toEqual([])
  })

  it('is empty for a pet who has died', () => {
    expect(calendarEvents(pet({ diedOn: '2026-09-01' }), NOW)).toEqual([])
  })

  it('says nothing diagnosis-shaped and sells nothing', () => {
    const text = calendarEvents(pet(), NOW).map((e) => e.title + ' ' + e.description).join(' ')
    expect(text).not.toMatch(/diagnos|symptom|disease|buy|shop|offer|\$/i)
  })
})

describe('the .ics file', () => {
  const ev = calendarEvents(pet(), NOW)
  const ics = toIcs(pet(), ev, NOW)

  it('is a well-formed calendar with one event per date, CRLF throughout', () => {
    expect(ics.startsWith('BEGIN:VCALENDAR\r\nVERSION:2.0\r\n')).toBe(true)
    expect(ics.trimEnd().endsWith('END:VCALENDAR')).toBe(true)
    expect(ics.match(/BEGIN:VEVENT/g)?.length).toBe(ev.length)
    expect(ics.replace(/\r\n/g, '')).not.toMatch(/\n/)
  })

  it('uses stable ids, so adding it again updates rather than duplicates', () => {
    expect(toIcs(pet(), ev, new Date('2026-10-02T09:00:00Z')).match(/UID:[^\r]+/g)).toEqual(ics.match(/UID:[^\r]+/g))
  })

  it('escapes commas and semicolons, and folds long lines at 75 octets', () => {
    for (const line of ics.split('\r\n')) expect(new TextEncoder().encode(line).length).toBeLessThanOrEqual(75)
    expect(ics).toContain('\\,')
    const odd = toIcs(pet({ name: 'Mr; Biscuit, Esq' }), calendarEvents(pet({ name: 'Mr; Biscuit, Esq' }), NOW), NOW)
    // Compared unfolded, as a calendar reads it: a long title may fold mid-name.
    expect(odd.replace(/\r\n /g, '')).toContain(String.raw`Mr\; Biscuit\, Esq`)
  })

  it('Gotcha Day repeats every year, and reminders come at 9am', () => {
    expect(ics).toContain('RRULE:FREQ=YEARLY')
    expect(ics).toContain('TRIGGER;RELATED=START:PT9H')
  })
})
