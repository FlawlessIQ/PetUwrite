/**
 * The fitness adapter (SPEC §6.9 — "CloTag readiness").
 *
 * SPEC IS EXPLICIT THAT THIS IS THE SEAM AND NOT THE HARDWARE: "do NOT build
 * hardware integration". Conor is diligencing Tractive, Fi and PetPace; which
 * one lands changes the SDK entirely and changes nothing above this interface.
 *
 * What that buys: every surface — the score, the nudge, the step count — reads
 * `activity`, `sleep` and `vitals` from a provider rather than from a hash
 * buried in `platform.ts`. When a partner SDK arrives it implements this and
 * no surface is touched.
 *
 * `SimulatedProvider` is deliberately NOT random. It is derived from the pet's
 * id and their declared routine, so the demo is stable across reloads and in
 * front of investors, and so two people looking at Max see the same Max. It
 * also reports `simulated: true`, which every surface showing its numbers uses
 * to say so — a fabricated step count presented as a measurement would be the
 * single most dishonest thing in the product.
 */
import type { PetProfile } from '../data/types'

export interface ActivityReading {
  /** Steps, or the species equivalent of movement, for the day. */
  steps: number
  /** Last seven days, oldest first, as a relative index. */
  trend: number[]
  /** True when the trend is meaningfully below this pet's own normal. */
  belowNormal: boolean
}

export interface SleepReading {
  hours: number
  /** Times woken, as a rough count. */
  disturbances: number
}

export interface VitalsReading {
  /** Resting respiratory rate, breaths per minute. */
  restingRespiratoryRate: number | null
  restingHeartRate: number | null
}

export interface FitnessProvider {
  id: string
  /** What the surfaces must disclose. */
  simulated: boolean
  /** Null when nothing is paired. */
  deviceId(pet: PetProfile): string | null
  activity(pet: PetProfile, now: Date): ActivityReading
  sleep(pet: PetProfile, now: Date): SleepReading
  vitals(pet: PetProfile, now: Date): VitalsReading
}

/** Stable 32-bit hash. Same input, same output, forever. */
function hash(seed: string): number {
  let h = 2166136261
  for (let i = 0; i < seed.length; i++) {
    h ^= seed.charCodeAt(i)
    h = Math.imul(h, 16777619)
  }
  return Math.abs(h)
}

function seeded(seed: string, lo: number, hi: number): number {
  return lo + (hash(seed) % (hi - lo + 1))
}

/**
 * The provider in front of everybody today.
 *
 * Derived from the pet's id and their declared routine — never from a clock and
 * never from `Math.random`, so the number on screen does not change while an
 * investor is looking at it.
 */
export const SimulatedProvider: FitnessProvider = {
  id: 'simulated',
  simulated: true,

  deviceId() {
    // Nothing is paired, and saying so is the honest answer. A fake device id
    // would make a fabricated reading look sourced.
    return null
  },

  activity(pet) {
    const isCat = pet.species === 'cat'
    const base = isCat ? seeded(pet.id + 's', 900, 2600) : seeded(pet.id + 's', 4200, 11000)
    const activity = pet.activity ?? 'moderate'
    const mul = activity === 'high' ? 1.35 : activity === 'low' ? 0.62 : 1
    // Max's story is a dip; everybody else trends flat or up.
    const belowNormal = pet.id === 'demo-max' || activity === 'low'
    return {
      steps: Math.round(base * mul),
      trend: belowNormal ? [10, 8, 13, 9, 15, 22, 26] : [18, 14, 16, 12, 14, 11, 12],
      belowNormal,
    }
  },

  sleep(pet) {
    const isCat = pet.species === 'cat'
    return {
      hours: isCat ? seeded(pet.id + 'z', 13, 17) : seeded(pet.id + 'z', 10, 14),
      disturbances: seeded(pet.id + 'q', 0, 4),
    }
  },

  vitals() {
    // Resting respiratory rate is the one home measurement with real clinical
    // value, which is exactly why it is not invented here: a fabricated one
    // could be read as reassurance about a heart. Null until a device reports.
    return { restingRespiratoryRate: null, restingHeartRate: null }
  },
}

/** What a surface must say when it is showing simulated numbers. */
export const SIMULATED_DISCLOSURE =
  'Activity and sleep figures here are simulated — there is no tracker connected. They are derived from what you have told us so they stay consistent with the rest of the profile.'

let current: FitnessProvider = SimulatedProvider

/** Swapped once a partner SDK lands. No surface changes. */
export function setFitnessProvider(p: FitnessProvider): void {
  current = p
}

export function fitnessProvider(): FitnessProvider {
  return current
}
