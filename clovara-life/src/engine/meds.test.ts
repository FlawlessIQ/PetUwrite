import { describe, expect, it } from 'vitest'
import * as meds from './meds'
import {
  medLine,
  medState,
  MISSED_DOSE,
  NOT_A_PRESCRIPTION,
  RUNNING_OUT_DAYS,
  RUNNING_OUT_NOTE,
  type Medication,
} from './meds'

const NOW = new Date('2026-09-24T18:00:00Z')
const at = (daysAgo: number, hour = 9) =>
  new Date(Date.UTC(2026, 8, 24 - daysAgo, hour)).toISOString()

const med = (over: Partial<Medication> = {}): Medication => ({
  id: 'm1',
  name: 'Metacam',
  amount: 'Half a tablet',
  frequency: 'twice',
  startedOn: at(10),
  given: [],
  ...over,
})

describe('it records and never advises', () => {
  it('exports nothing that decides a dose', () => {
    for (const name of Object.keys(meds)) {
      expect(name, `meds exports "${name}"`).not.toMatch(
        /shouldGive|recommendDose|calculateDose|adjust|skip|doubleDose|safeAmount/i,
      )
    }
  })

  it('says a missed dose is a question for the vet, with no general answer', () => {
    expect(MISSED_DOSE).toMatch(/ask your vet/i)
    expect(MISSED_DOSE).toMatch(/no general answer/i)
    expect(MISSED_DOSE).not.toMatch(/\b(give|skip|double|wait until|take it now)\b/i)
  })

  it('says we do not check the prescription and never will', () => {
    expect(NOT_A_PRESCRIPTION).toMatch(/we do not check it/i)
    expect(NOT_A_PRESCRIPTION).toMatch(/never tell you to change it/i)
  })

  it('keeps the amount as free text rather than a parsed dose', () => {
    // We do not look a drug up, do not know a standard dose, and do not check
    // one against a weight. A plausible-looking correction to somebody's
    // prescription is the worst thing this could produce.
    const m = med({ amount: 'Half a tablet with food' })
    expect(m.amount).toBe('Half a tablet with food')
    expect(medLine(m, medState(m, NOW))).not.toMatch(/\d+\s*(mg|ml)/)
  })
})

describe('who gave it is deliberately not recorded', () => {
  it('a dose is a timestamp and nothing else', () => {
    const m = med({ given: [at(0)] })
    expect(typeof m.given[0]).toBe('string')
    // No uid anywhere in the shape: that it was given prevents the double dose,
    // which is the whole safety value. Who gave it turns a shared record into a
    // ledger of who forgot.
    expect(JSON.stringify(m)).not.toMatch(/uid|by|who/i)
  })
})

describe('running out', () => {
  it('counts down from what was dispensed', () => {
    const m = med({ quantity: 20, given: [at(2), at(1), at(0)] })
    const s = medState(m, NOW)
    expect(s.remaining).toBe(17)
    expect(s.daysLeft).toBe(8)
    expect(s.runningOut).toBe(false)
  })

  it('flags when it is close', () => {
    const s = medState(med({ quantity: 6, given: [at(1)] }), NOW)
    expect(s.daysLeft).toBeLessThanOrEqual(RUNNING_OUT_DAYS)
    expect(s.runningOut).toBe(true)
  })

  it('says nothing when the quantity is unknown', () => {
    const s = medState(med(), NOW)
    expect(s.remaining).toBeNull()
    expect(s.daysLeft).toBeNull()
    expect(s.runningOut).toBe(false)
  })

  it('refuses to count an irregular course rather than guessing', () => {
    // Guessing a schedule would be the first piece of advice.
    const s = medState(med({ frequency: 'other', quantity: 30 }), NOW)
    expect(s.daysLeft).toBeNull()
  })

  it('never goes negative', () => {
    const s = medState(med({ quantity: 2, given: [at(2), at(1), at(0)] }), NOW)
    expect(s.remaining).toBe(0)
    expect(s.daysLeft).toBe(0)
    expect(medLine(med({ quantity: 2, given: [at(2), at(1), at(0)] }), s)).toMatch(/last of it/i)
  })

  it('attributes the count to the owner, not to us', () => {
    const s = medState(med({ quantity: 20, given: [] }), NOW)
    expect(medLine(med({ quantity: 20 }), s)).toMatch(/by your count/i)
    expect(RUNNING_OUT_NOTE).toMatch(/from what you told us/i)
    expect(RUNNING_OUT_NOTE).toMatch(/not always same-day/i)
  })
})

describe('today', () => {
  it('counts only today, and knows when the day is done', () => {
    const m = med({ given: [at(1), at(0, 8), at(0, 14)] })
    const s = medState(m, NOW)
    expect(s.givenToday).toBe(2)
    expect(s.doneToday).toBe(true)
  })

  it('is not done when one of two is logged', () => {
    const s = medState(med({ given: [at(0, 8)] }), NOW)
    expect(s.givenToday).toBe(1)
    expect(s.doneToday).toBe(false)
  })

  it('is never "done" for an irregular course', () => {
    expect(medState(med({ frequency: 'other', given: [at(0)] }), NOW).doneToday).toBe(false)
    expect(medLine(med({ frequency: 'other' }), medState(med({ frequency: 'other' }), NOW))).toMatch(
      /Logged as you go/i,
    )
  })

  it('handles a medication with no doses logged at all', () => {
    const s = medState(med(), NOW)
    expect(s.givenToday).toBe(0)
    expect(medLine(med(), s)).toMatch(/0 of 2 logged today/)
  })
})
