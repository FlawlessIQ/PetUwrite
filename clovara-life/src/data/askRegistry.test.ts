import { describe, expect, it } from 'vitest'
// `?raw` rather than node:fs — the app project deliberately carries no node
// types, and Vite hands us the source either way.
import sharpenSource from '../components/Sharpen.tsx?raw'
import { ASK_REGISTRY, asksFor, fieldsOn } from './askRegistry'
import type { PetProfile } from './types'

const pet = (over: Partial<PetProfile> = {}): PetProfile => ({
  id: 'p',
  name: 'Scout',
  species: 'dog',
  breedId: 'labrador-retriever',
  birthDate: '2021-04-02',
  sex: 'female',
  weightLb: 0,
  conditionIds: [],
  ...over,
})

describe('the registry places every ask on a screen where it does something', () => {
  it('gives every ask a question and a benefit', () => {
    for (const a of ASK_REGISTRY) {
      expect(a.question.length, a.field).toBeGreaterThan(8)
      expect(a.benefit.length, a.field).toBeGreaterThan(20)
    }
  })

  it('never justifies an ask by our own completeness', () => {
    // SPEC §4: "no field asked without visible benefit". If the only reason is
    // that our record has a gap, it should not be asked at all.
    for (const a of ASK_REGISTRY) {
      expect(a.benefit, a.field).not.toMatch(
        /complete your profile|finish setting up|for our records|helps us/i,
      )
    }
  })

  it('asks each field in exactly one place', () => {
    const fields = ASK_REGISTRY.map((a) => a.field)
    expect(new Set(fields).size, fields.join(', ')).toBe(fields.length)
  })

  it('keeps SPEC §4.3\'s own examples where SPEC puts them', () => {
    expect(fieldsOn('shop')).toContain('diet')
    expect(fieldsOn('lost-pet-card')).toContain('microchipId')
    expect(fieldsOn('attach')).toContain('ownerAddress')
    expect(fieldsOn('trial-end')).toContain('paymentMethod')
  })

  it('never asks for identity or payment on a pet screen', () => {
    // These belong to the person and to Stripe. A pet record that accumulates
    // an address is a different kind of database from the one we said we were
    // building.
    for (const trigger of ['life', 'shop'] as const) {
      for (const a of asksFor(trigger, pet())) {
        expect(a.storedOn, `${trigger}/${a.field}`).toBeUndefined()
      }
    }
    expect(ASK_REGISTRY.find((a) => a.field === 'ownerAddress')?.storedOn).toBe('household')
    expect(ASK_REGISTRY.find((a) => a.field === 'paymentMethod')?.storedOn).toBe('stripe')
  })

  it('only asks for payment at trial end, never to start one', () => {
    // SPEC §1: trial-only membership. Asking for a card up front is a different
    // product and a worse one.
    const payment = ASK_REGISTRY.find((a) => a.field === 'paymentMethod')!
    expect(payment.trigger).toBe('trial-end')
    expect(payment.benefit).toMatch(/never to start one/i)
  })
})

describe('asksFor narrows to the pet in front of you', () => {
  it('never asks a dog the cat question, or a cat the dog one', () => {
    const dogFields = asksFor('life', pet()).map((a) => a.field)
    const catFields = asksFor('life', pet({ species: 'cat', breedId: 'domestic-shorthair' })).map(
      (a) => a.field,
    )
    expect(dogFields).not.toContain('outdoorAccess')
    expect(catFields).toContain('outdoorAccess')
    expect(catFields).not.toContain('neuterAgeBand')
  })

  it('asks age-at-neuter only once neutering is known and true', () => {
    const has = (p: PetProfile) => asksFor('life', p).some((a) => a.field === 'neuterAgeBand')
    expect(has(pet())).toBe(false)
    expect(has(pet({ neutered: false }))).toBe(false)
    expect(has(pet({ neutered: true }))).toBe(true)
    expect(has(pet({ neutered: true, neuterAgeBand: 'under-6m' }))).toBe(false)
  })

  it('stops asking once answered', () => {
    expect(asksFor('shop', pet()).map((a) => a.field)).toContain('diet')
    expect(asksFor('shop', pet({ diet: 'measured' })).map((a) => a.field)).not.toContain('diet')
  })

  it('returns nothing for a screen with no asks for this pet', () => {
    expect(asksFor('attach', pet()).every((a) => a.trigger === 'attach')).toBe(true)
  })
})

describe('the registry is enforced, not advisory', () => {
  /**
   * The load-bearing test. Sharpen renders the Tier-1 questions; if someone
   * adds a control there without registering it, this fails — which is the
   * whole reason the registry exists rather than a comment saying "ask things
   * in the right place".
   */
  it('Sharpen asks for nothing the registry does not place on the Life surface', () => {
    const asked = [...sharpenSource.matchAll(/<Question\s+field="([a-zA-Z]+)"/g)].map((m) => m[1])
    expect(asked.length, 'no <Question field="..."> found — did the markup change?').toBeGreaterThan(
      4,
    )
    const placed = new Set(fieldsOn('life'))
    for (const field of asked) {
      expect(placed.has(field), `Sharpen asks for "${field}", which the registry does not place on 'life'`).toBe(true)
    }
  })

  it('the registry does not place anything on Life that Sharpen forgot to ask', () => {
    const asked = new Set([...sharpenSource.matchAll(/<Question\s+field="([a-zA-Z]+)"/g)].map((m) => m[1]))
    for (const field of fieldsOn('life')) {
      expect(asked.has(field), `registry places "${field}" on 'life' but Sharpen never asks it`).toBe(
        true,
      )
    }
  })
})
