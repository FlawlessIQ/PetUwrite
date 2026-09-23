import { describe, expect, it } from 'vitest'
import { vaccineState, vaccineHeadline, COURSE_VISIBLE_WEEKS } from './vaccines'
import {
  CORE_VACCINES,
  NON_CORE_TO_ASK,
  VACCINE_DISCLAIMER,
  VACCINE_DOSES,
  VACCINE_RECORD_NOTE,
} from '../data/vaccines'
import { WEEKS_PER_YEAR } from './passport'
import type { PetProfile } from '../data/types'

const NOW = new Date('2026-09-23T12:00:00Z')
const weeksOld = (w: number) =>
  new Date(NOW.getTime() - (w / WEEKS_PER_YEAR) * 365.25 * 86_400_000).toISOString().slice(0, 10)

const pet = (over: Partial<PetProfile> = {}): PetProfile => ({
  id: 'p',
  name: 'Scout',
  species: 'dog',
  breedId: 'labrador-retriever',
  birthDate: weeksOld(8),
  sex: 'female',
  weightLb: 0,
  conditionIds: [],
  ...over,
})

describe('the content', () => {
  it('is core only — no lifestyle vaccine is ever scheduled', () => {
    // Leptospirosis, kennel cough, Lyme and FeLV depend on where somebody lives
    // and how the animal lives. Scheduling them would be recommending for an
    // animal we have never seen.
    const scheduled = VACCINE_DOSES.map((d) => d.vaccineId).join(' ')
    for (const nonCore of ['lepto', 'kennel', 'lyme', 'felv', 'leukaemia', 'bordetella']) {
      expect(scheduled.toLowerCase(), nonCore).not.toContain(nonCore)
    }
    expect(NON_CORE_TO_ASK.dog.join(' ')).toMatch(/Leptospirosis/)
    expect(NON_CORE_TO_ASK.cat.join(' ')).toMatch(/leukaemia/)
  })

  it('flags rabies as a matter of law rather than presenting it as universal', () => {
    // Mandated for most pets in the US, not routinely given in the UK or
    // Ireland outside travel. Omitting it or universalising it are both wrong.
    for (const v of CORE_VACCINES.filter((x) => x.id.endsWith('rabies'))) {
      expect(v.lawDependent).toBe(true)
      expect(v.protects).toMatch(/law where you live/i)
    }
  })

  it('says whose decision the schedule is, at the top', () => {
    expect(VACCINE_DISCLAIMER).toMatch(/your vet sets the schedule/i)
    expect(VACCINE_DISCLAIMER).toMatch(/brands differ/i)
  })

  it('says a recorded date is not a medical record', () => {
    expect(VACCINE_RECORD_NOTE).toMatch(/not a medical record/i)
    expect(VACCINE_RECORD_NOTE).toMatch(/does not reach your vet/i)
  })

  it('never names a dose, a volume or a product', () => {
    const blob = [...CORE_VACCINES.map((v) => `${v.label} ${v.protects}`), ...VACCINE_DOSES.map((d) => d.label)].join(' ')
    expect(blob).not.toMatch(/\b(\d+\s*(ml|mg)|subcutaneous|intranasal|\bIM\b)\b/i)
  })

  it('stops after the first booster rather than inventing adult dates', () => {
    // Adult intervals depend on the product used and on local guidance. A date
    // we cannot know should not appear as though we know it.
    const adult = VACCINE_DOSES.filter((d) => d.fromWeeks > 100)
    expect(adult).toHaveLength(0)
  })
})

describe('where a pet is in the course', () => {
  it('has the first dose due for an eight-week-old puppy', () => {
    const s = vaccineState(pet(), NOW)
    expect(s.dueNow.some((d) => d.dose.id === 'dog-dhp-1')).toBe(true)
    expect(vaccineHeadline(pet(), s)).toMatch(/usually given/i)
  })

  it('gives a cat the cat course and never the dog one', () => {
    const s = vaccineState(pet({ species: 'cat', breedId: 'domestic-shorthair' }), NOW)
    expect(s.doses.every((d) => d.dose.vaccineId.startsWith('cat'))).toBe(true)
    expect(s.doses.some((d) => d.vaccine.label === 'FVRCP')).toBe(true)
  })

  it('marks a recorded dose as recorded whatever the age', () => {
    const s = vaccineState(
      pet({ vaccineRecords: [{ doseId: 'dog-dhp-1', givenOn: '2026-08-01' }] }),
      NOW,
    )
    const d = s.doses.find((x) => x.dose.id === 'dog-dhp-1')!
    expect(d.status).toBe('recorded')
    expect(d.givenOn).toBe('2026-08-01')
    expect(s.recordedCount).toBe(1)
  })

  it('calls a missed window "past-window", never "overdue"', () => {
    // The commonest reason a dose is missing here is that nobody typed it in.
    // Telling somebody their puppy is unprotected on that evidence would be
    // both wrong and frightening.
    // 22 weeks: the primary course windows have all passed and the adult
    // booster window (26w+) has not opened, so nothing is competing for the
    // headline.
    const s = vaccineState(pet({ birthDate: weeksOld(22) }), NOW)
    expect(s.pastWindow.length).toBeGreaterThan(0)
    expect(s.dueNow).toHaveLength(0)
    const headline = vaccineHeadline(pet({ birthDate: weeksOld(22) }), s)
    expect(headline).not.toMatch(/overdue|unprotected|at risk|missed/i)
    expect(headline).toMatch(/if .* has already had these, record them/i)
  })

  it('computes window dates from the birthday', () => {
    const s = vaccineState(pet(), NOW)
    const first = s.doses.find((d) => d.dose.id === 'dog-dhp-1')!
    const weeks = (first.windowOpens.getTime() - Date.parse(pet().birthDate)) / (7 * 86_400_000)
    expect(Math.round(weeks)).toBe(6)
    expect(first.windowCloses.getTime()).toBeGreaterThan(first.windowOpens.getTime())
  })

  it('every dose is upcoming for a newborn and none are due', () => {
    const s = vaccineState(pet({ birthDate: weeksOld(1) }), NOW)
    expect(s.doses.every((d) => d.status === 'upcoming')).toBe(true)
    expect(vaccineHeadline(pet({ birthDate: weeksOld(1) }), s)).toMatch(/nothing due/i)
  })

  it('disappears for an adult with nothing recorded, and stays for one with records', () => {
    const old = pet({ birthDate: weeksOld(COURSE_VISIBLE_WEEKS + 20) })
    expect(vaccineState(old, NOW).visible).toBe(false)
    expect(
      vaccineState({ ...old, vaccineRecords: [{ doseId: 'dog-dhp-1', givenOn: '2020-01-01' }] }, NOW)
        .visible,
    ).toBe(true)
  })

  it('never says a pet is protected', () => {
    // Whether a course worked is a clinical question, and titre is a real thing
    // we have no access to.
    for (const weeks of [2, 8, 16, 60, 200]) {
      const p = pet({ birthDate: weeksOld(weeks) })
      const h = vaccineHeadline(p, vaccineState(p, NOW))
      expect(h, `${weeks}w`).not.toMatch(/protected|covered|immune|safe now/i)
    }
  })
})
