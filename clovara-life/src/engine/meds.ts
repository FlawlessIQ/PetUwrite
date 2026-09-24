/**
 * Meds autopilot (SPEC-HORIZON §1.4): what they take, when it runs out, and
 * whether today's dose happened.
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * IT RECORDS. IT NEVER ADVISES.
 *
 * Not what to give, not how much, not what to do about a missed one, not
 * whether to stop. Every one of those is prescribing, and a missed-dose screen
 * that says anything other than "ask your vet" is prescribing in the most
 * tempting place to do it.
 *
 * NOTHING IS CARRIED THAT WE WERE NOT TOLD. The owner types what is on the
 * label. We do not look a drug up, we do not know a standard dose, and we do
 * not check one against a weight — a plausible-looking correction to somebody's
 * prescription is the worst thing this could produce.
 *
 * WHO LOGGED A DOSE IS NOT RECORDED (SPEC-HORIZON §1.4's open question). That
 * it was given prevents the double dose, which is the whole safety value. Who
 * gave it adds nothing clinical and turns a shared household record into a
 * ledger of what each person did or forgot.
 * ═══════════════════════════════════════════════════════════════════════════
 *
 * Pure; clock injected.
 */

/** How often, in the owner's words, and how many times a day that is. */
export const FREQUENCIES = [
  { id: 'once', label: 'Once a day', perDay: 1 },
  { id: 'twice', label: 'Twice a day', perDay: 2 },
  { id: 'three', label: 'Three times a day', perDay: 3 },
  { id: 'other', label: 'Something else', perDay: 0 },
] as const

export type FrequencyId = (typeof FREQUENCIES)[number]['id']

export interface Medication {
  id: string
  /** Exactly what is on the label. Never interpreted. */
  name: string
  /** What the owner was told to give. Free text, never parsed into a dose. */
  amount: string
  frequency: FrequencyId
  startedOn: string
  /** How many were dispensed, if they know. */
  quantity?: number
  /** ISO timestamps. No uid — see the header. */
  given: string[]
}

export interface MedState {
  /** Doses left, when quantity and a regular frequency are both known. */
  remaining: number | null
  /** Whole days until it runs out. Null when we cannot say. */
  daysLeft: number | null
  /** Doses recorded today. */
  givenToday: number
  /** How many a day there should be, 0 when irregular. */
  perDay: number
  /** True when every expected dose today is logged. */
  doneToday: boolean
  runningOut: boolean
}

/** Runs out within this many days is worth surfacing. */
export const RUNNING_OUT_DAYS = 5

const sameDay = (iso: string, now: Date) =>
  new Date(iso).toISOString().slice(0, 10) === now.toISOString().slice(0, 10)

export function medState(med: Medication, now: Date): MedState {
  const perDay = FREQUENCIES.find((f) => f.id === med.frequency)?.perDay ?? 0
  const given = med.given ?? []
  const givenToday = given.filter((g) => sameDay(g, now)).length

  // Only computable with a quantity AND a regular frequency. An irregular
  // course cannot be counted down, and guessing would be the first advice.
  const remaining =
    med.quantity !== undefined && med.quantity >= 0
      ? Math.max(0, med.quantity - given.length)
      : null
  const daysLeft = remaining !== null && perDay > 0 ? Math.floor(remaining / perDay) : null

  return {
    remaining,
    daysLeft,
    givenToday,
    perDay,
    doneToday: perDay > 0 && givenToday >= perDay,
    runningOut: daysLeft !== null && daysLeft <= RUNNING_OUT_DAYS,
  }
}

/**
 * What to say about where a course is. Never what to do about it.
 */
export function medLine(_med: Medication, state: MedState): string {
  if (state.daysLeft === null) {
    return state.perDay > 0
      ? `${state.givenToday} of ${state.perDay} logged today.`
      : 'Logged as you go.'
  }
  if (state.daysLeft === 0) return 'This is the last of it, by your count.'
  return `About ${state.daysLeft} day${state.daysLeft === 1 ? '' : 's'} left, by your count.`
}

/** The one thing said about a missed dose, and it is not advice. */
export const MISSED_DOSE =
  'If a dose was missed, ask your vet what to do about it. There is no general answer — it depends on the medicine, and getting it wrong in either direction matters.'

export const NOT_A_PRESCRIPTION =
  'This is your note of what you were told. We do not check it, we do not know what the dose should be, and we will never tell you to change it.'

export const RUNNING_OUT_NOTE =
  'Counted from what you told us was dispensed and how often you log it. Order more before it matters — repeat prescriptions are not always same-day.'
