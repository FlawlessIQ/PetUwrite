/**
 * Vaccine Autopilot (SPEC §6.4): where a pet is in the core course.
 *
 * Pure; clock injected.
 *
 * `overdue` deliberately does not exist as a status. A dose can be PAST ITS
 * TYPICAL WINDOW, which is a prompt to ask a vet — but calling it overdue would
 * assert that we know it was not given, and the commonest reason a dose is not
 * recorded here is that nobody has typed it in. The distinction is the whole
 * difference between a reminder and an accusation.
 */
import { CORE_VACCINES, VACCINE_DOSES, type CoreVaccine, type VaccineDose } from '../data/vaccines'
import type { PetProfile, Species } from '../data/types'
import { ageInYears } from './project'
import { WEEKS_PER_YEAR } from './passport'

export type DoseStatus =
  /** Recorded as given. */
  | 'recorded'
  /** The typical window is now. */
  | 'due'
  /** Still ahead. */
  | 'upcoming'
  /** The window has passed with nothing recorded. Ask, do not assume. */
  | 'past-window'

export interface DoseState {
  dose: VaccineDose
  vaccine: CoreVaccine
  status: DoseStatus
  /** ISO date the owner recorded, if any. */
  givenOn?: string
  /** Approximate calendar date the window opens, from the birthday. */
  windowOpens: Date
  windowCloses: Date
}

export interface VaccineState {
  visible: boolean
  ageWeeks: number
  doses: DoseState[]
  /** The ones worth surfacing now. */
  dueNow: DoseState[]
  pastWindow: DoseState[]
  recordedCount: number
}

/** Past this we stop showing a primary course that is long finished. */
export const COURSE_VISIBLE_WEEKS = 130

function addWeeks(iso: string, weeks: number): Date {
  return new Date(Date.parse(iso) + weeks * 7 * 86_400_000)
}

export function vaccineState(pet: PetProfile, now: Date): VaccineState {
  const ageWeeks = ageInYears(pet.birthDate, now) * WEEKS_PER_YEAR
  const records = new Map((pet.vaccineRecords ?? []).map((r) => [r.doseId, r.givenOn]))

  const forSpecies = (s: Species) => VACCINE_DOSES.filter((d) => d.vaccineId.startsWith(s))
  const vaccineById = new Map(CORE_VACCINES.map((v) => [v.id, v]))

  const doses: DoseState[] = forSpecies(pet.species).map((dose) => {
    const vaccine = vaccineById.get(dose.vaccineId)!
    const givenOn = records.get(dose.id)
    const status: DoseStatus = givenOn
      ? 'recorded'
      : ageWeeks < dose.fromWeeks
        ? 'upcoming'
        : ageWeeks <= dose.toWeeks
          ? 'due'
          : 'past-window'
    return {
      dose,
      vaccine,
      status,
      givenOn,
      windowOpens: addWeeks(pet.birthDate, dose.fromWeeks),
      windowCloses: addWeeks(pet.birthDate, dose.toWeeks),
    }
  })

  return {
    visible: ageWeeks < COURSE_VISIBLE_WEEKS || doses.some((d) => d.status === 'recorded'),
    ageWeeks,
    doses,
    dueNow: doses.filter((d) => d.status === 'due'),
    pastWindow: doses.filter((d) => d.status === 'past-window'),
    recordedCount: doses.filter((d) => d.status === 'recorded').length,
  }
}

/**
 * The line at the top.
 *
 * Never "Scout is overdue". The most likely reason a dose is missing from this
 * list is that nobody typed it in, and telling somebody their puppy is
 * unprotected on that evidence would be both wrong and frightening.
 */
export function vaccineHeadline(pet: PetProfile, state: VaccineState): string {
  if (state.dueNow.length > 0) {
    const names = [...new Set(state.dueNow.map((d) => d.vaccine.label))].join(' and ')
    return `Around now is when ${names} is usually given.`
  }
  if (state.pastWindow.length > 0) {
    return `Some of the usual window has passed. If ${pet.name} has already had these, record them; if not, it is worth a call.`
  }
  const next = state.doses.find((d) => d.status === 'upcoming')
  if (next) return `Nothing due. Next is usually ${next.vaccine.label}, ${next.dose.label.toLowerCase()}.`
  return 'The core course is recorded. Your vet will tell you when the next booster is due.'
}
