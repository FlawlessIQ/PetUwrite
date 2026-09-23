import { afterEach, describe, expect, it } from 'vitest'
import {
  SimulatedProvider,
  SIMULATED_DISCLOSURE,
  fitnessProvider,
  setFitnessProvider,
  type FitnessProvider,
} from './provider'
import type { PetProfile } from '../data/types'

const NOW = new Date('2026-09-23T12:00:00Z')
const pet = (over: Partial<PetProfile> = {}): PetProfile => ({
  id: 'pet-a',
  name: 'Scout',
  species: 'dog',
  breedId: 'labrador-retriever',
  birthDate: '2021-04-02',
  sex: 'female',
  weightLb: 68,
  conditionIds: [],
  ...over,
})

afterEach(() => setFitnessProvider(SimulatedProvider))

describe('the simulated provider', () => {
  it('says it is simulated, which every surface showing it must disclose', () => {
    // A fabricated step count presented as a measurement would be the single
    // most dishonest thing in the product.
    expect(SimulatedProvider.simulated).toBe(true)
    expect(SIMULATED_DISCLOSURE).toMatch(/simulated/i)
    expect(SIMULATED_DISCLOSURE).toMatch(/no tracker connected/i)
  })

  it('reports no device, rather than inventing one', () => {
    // A fake device id would make a fabricated reading look sourced.
    expect(SimulatedProvider.deviceId(pet())).toBeNull()
  })

  it('is deterministic — the number does not move while somebody is looking', () => {
    const a = SimulatedProvider.activity(pet(), NOW)
    const b = SimulatedProvider.activity(pet(), new Date('2027-01-01T00:00:00Z'))
    expect(a.steps).toBe(b.steps)
    expect(a.trend).toEqual(b.trend)
  })

  it('gives different pets different numbers', () => {
    expect(SimulatedProvider.activity(pet({ id: 'pet-a' }), NOW).steps).not.toBe(
      SimulatedProvider.activity(pet({ id: 'pet-b' }), NOW).steps,
    )
  })

  it('moves with the routine somebody declared', () => {
    const low = SimulatedProvider.activity(pet({ activity: 'low' }), NOW).steps
    const high = SimulatedProvider.activity(pet({ activity: 'high' }), NOW).steps
    expect(high).toBeGreaterThan(low)
  })

  it('gives a cat a cat-sized number', () => {
    const cat = SimulatedProvider.activity(pet({ species: 'cat', breedId: 'domestic-shorthair' }), NOW)
    const dog = SimulatedProvider.activity(pet(), NOW)
    expect(cat.steps).toBeLessThan(dog.steps)
  })

  it('keeps Max\'s dip, which the demo turns on', () => {
    expect(SimulatedProvider.activity(pet({ id: 'demo-max' }), NOW).belowNormal).toBe(true)
  })

  it('NEVER invents a resting respiratory rate', () => {
    // The one home measurement with real clinical value. A fabricated one could
    // be read as reassurance about a heart, so it stays null until a device
    // actually reports it.
    const v = SimulatedProvider.vitals(pet(), NOW)
    expect(v.restingRespiratoryRate).toBeNull()
    expect(v.restingHeartRate).toBeNull()
  })

  it('sleeps a cat longer than a dog', () => {
    const cat = SimulatedProvider.sleep(pet({ species: 'cat', breedId: 'domestic-shorthair' }), NOW)
    expect(cat.hours).toBeGreaterThanOrEqual(13)
  })
})

describe('the seam', () => {
  it('starts on the simulated provider', () => {
    expect(fitnessProvider().id).toBe('simulated')
  })

  it('swaps for a partner SDK without a surface knowing', () => {
    // The whole point of SPEC §6.9: Tractive, Fi or PetPace drops in here.
    const fake: FitnessProvider = {
      id: 'tractive',
      simulated: false,
      deviceId: () => 'TR-12345',
      activity: () => ({ steps: 9999, trend: [1, 2, 3, 4, 5, 6, 7], belowNormal: false }),
      sleep: () => ({ hours: 11, disturbances: 1 }),
      vitals: () => ({ restingRespiratoryRate: 22, restingHeartRate: 78 }),
    }
    setFitnessProvider(fake)
    expect(fitnessProvider().id).toBe('tractive')
    expect(fitnessProvider().simulated).toBe(false)
    expect(fitnessProvider().deviceId(pet())).toBe('TR-12345')
    expect(fitnessProvider().vitals(pet(), NOW).restingRespiratoryRate).toBe(22)
  })
})
