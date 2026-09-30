import { describe, expect, it } from 'vitest'
import { MAX_ASKS, shouldAskToSave, worthKeeping } from './savePrompt'
import type { PetProfile } from '../data/types'

const pup = (over: Partial<PetProfile> = {}): PetProfile => ({
  id: 'p', name: 'Bruno', species: 'dog', breedId: 'labrador-retriever', birthDate: '2026-07-25',
  sex: 'male', weightLb: 0, conditionIds: [], ...over,
})
const out = { signedIn: false, memory: null }

describe('asking to keep the plan', () => {
  it('asks straight after the reveal', () => {
    expect(shouldAskToSave(pup(), out)).toBe(true)
  })

  it('never asks a signed-in owner, about a demo pet, or about a pet who has died', () => {
    expect(shouldAskToSave(pup(), { signedIn: true, memory: null })).toBe(false)
    expect(shouldAskToSave(pup({ demo: true }), out)).toBe(false)
    expect(shouldAskToSave(pup({ diedOn: '2026-09-01' }), out)).toBe(false)
  })

  it('after one "not now", waits for something new worth keeping', () => {
    const memory = { dismissals: 1, keptAtDismissal: worthKeeping(pup()) }
    expect(shouldAskToSave(pup(), { signedIn: false, memory })).toBe(false)
    expect(shouldAskToSave(pup({ socialStamps: ['calm-child'] }), { signedIn: false, memory })).toBe(true)
  })

  it('does not count what was already there when they said no', () => {
    const stamped = pup({ socialStamps: ['calm-child', 'toddler'] })
    const memory = { dismissals: 1, keptAtDismissal: worthKeeping(stamped) }
    expect(shouldAskToSave(stamped, { signedIn: false, memory })).toBe(false)
  })

  it(`never more than ${MAX_ASKS} times`, () => {
    const memory = { dismissals: MAX_ASKS, keptAtDismissal: 0 }
    expect(shouldAskToSave(pup({ socialStamps: ['a', 'b', 'c'], dental: 'daily' }), { signedIn: false, memory })).toBe(false)
  })
})

describe('what counts as worth keeping', () => {
  it('is nothing after the five reveal questions', () => {
    expect(worthKeeping(pup())).toBe(0)
  })

  it('grows with answers, stamps, vaccinations and medication', () => {
    expect(worthKeeping(pup({ dental: 'weekly', socialStamps: ['a'], vaccineRecords: [{ doseId: 'd', givenOn: '2026-09-01' }] }))).toBe(3)
  })
})
