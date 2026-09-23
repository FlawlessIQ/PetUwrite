import { describe, expect, it } from 'vitest'
import { profileFromFirestore, storedFromProfile } from './fromFirestore'
import type { StoredPet } from './stored'
import { project } from '../engine/project'
import type { PetProfile } from './types'

const NOW = new Date('2026-09-23T12:00:00Z')
const UID = 'uid-123'
const HH = 'hh-abc'

const profile = (over: Partial<PetProfile> = {}): PetProfile => ({
  id: 'pet-1',
  name: 'Scout',
  species: 'dog',
  breedId: 'labrador-retriever',
  birthDate: '2021-04-02',
  sex: 'female',
  neutered: true,
  weightLb: 68,
  conditionIds: [],
  activity: 'moderate',
  dental: 'weekly',
  diet: 'measured',
  ...over,
})

/** Only the four Tier-0 fields SPEC §4.1 collects before the reveal. */
const tier0Only = (over: Partial<StoredPet> = {}): StoredPet =>
  ({
    id: 'pet-1',
    householdId: HH,
    createdAt: NOW.toISOString(),
    createdBy: UID,
    name: { value: 'Scout', provenance: 'owner_declared', updatedAt: NOW.toISOString(), updatedBy: UID },
    species: { value: 'dog', provenance: 'owner_declared', updatedAt: NOW.toISOString(), updatedBy: UID },
    breedId: { value: 'labrador-retriever', provenance: 'owner_declared', updatedAt: NOW.toISOString(), updatedBy: UID },
    birthDate: { value: '2021-04-02', provenance: 'owner_declared', updatedAt: NOW.toISOString(), updatedBy: UID },
    ...over,
  }) as StoredPet

describe('profileFromFirestore — round trip', () => {
  it('survives profile → stored → profile without changing what the engine sees', () => {
    const before = profile()
    const stored = storedFromProfile(before, { householdId: HH, uid: UID, now: NOW })
    const after = profileFromFirestore(stored)!
    expect(after).not.toBeNull()
    expect(after.profile).toEqual(before)
    expect(after.assumed).toEqual([])
    // And the projection itself is identical, which is the claim that matters.
    expect(project(after.profile, { now: NOW })).toEqual(project(before, { now: NOW }))
  })

  it('round-trips the Phase 1 optional fields', () => {
    const before = profile({ neuterAgeBand: 'under-6m', headline: 'Hip note in 2024' })
    const cat = profile({
      id: 'pet-2',
      species: 'cat',
      breedId: 'domestic-shorthair',
      weightLb: 10,
      outdoorAccess: 'outdoor',
    })
    for (const p of [before, cat]) {
      const stored = storedFromProfile(p, { householdId: HH, uid: UID, now: NOW })
      expect(profileFromFirestore(stored)!.profile, p.id).toEqual(p)
    }
  })

  it('stamps provenance and authorship on everything it writes', () => {
    const stored = storedFromProfile(profile(), { householdId: HH, uid: UID, now: NOW })
    const fields = Object.values(stored).filter(
      (v): v is { provenance: string; updatedBy: string; updatedAt: string } =>
        !!v && typeof v === 'object' && 'provenance' in v,
    )
    expect(fields.length).toBeGreaterThan(8)
    for (const f of fields) {
      expect(f.provenance).toBe('owner_declared')
      expect(f.updatedBy).toBe(UID)
      expect(f.updatedAt).toBe(NOW.toISOString())
    }
  })

  it('writes only what was answered — a skipped field stays absent, not defaulted', () => {
    // weightLb 0 is how the app represents "not given". Writing it as a real
    // value would launder an assumption into an owner_declared fact.
    const stored = storedFromProfile(profile({ weightLb: 0 }), {
      householdId: HH,
      uid: UID,
      now: NOW,
    })
    expect(stored.weightLb).toBeUndefined()
    expect(stored.neuterAgeBand).toBeUndefined()
    expect(stored.outdoorAccess).toBeUndefined()
    expect(stored.headline).toBeUndefined()
  })

  it('records an import so a migrated pet is distinguishable later', () => {
    const stored = storedFromProfile(profile(), {
      householdId: HH,
      uid: UID,
      now: NOW,
      importedFrom: 'localStorage',
    })
    expect(stored.importedFrom).toBe('localStorage')
    expect(storedFromProfile(profile(), { householdId: HH, uid: UID, now: NOW }).importedFrom).toBeUndefined()
  })
})

describe('profileFromFirestore — "I don\'t know" is an answer', () => {
  it('projects a Tier-0-only pet without crashing', () => {
    const mapped = profileFromFirestore(tier0Only())!
    expect(mapped).not.toBeNull()
    const p = project(mapped.profile, { now: NOW })
    expect(p.healthyYearsRange.high).toBeGreaterThan(p.healthyYearsRange.low)
    expect(p.riskCards.length).toBeGreaterThanOrEqual(3)
    expect(p.stages.length).toBe(4)
  })

  it('EVERY default used for an unanswered field is a zero-delta reference', () => {
    // The load-bearing test of this module. An unanswered question must never
    // flatter a pet and never punish one — so mapping a Tier-0-only pet must
    // produce a projection whose only factors come from fields that were
    // actually answered. With nothing answered, nothing may have moved.
    const mapped = profileFromFirestore(tier0Only())!
    const p = project(mapped.profile, { now: NOW })
    expect(p.factors).toEqual([])
  })

  it('reports what it assumed, in plain words, without inventing a figure', () => {
    const mapped = profileFromFirestore(tier0Only())!
    const fields = mapped.assumed.map((a) => a.field).sort()
    expect(fields).toEqual(
      ['activity', 'conditionIds', 'dental', 'diet', 'neutered', 'sex', 'weightLb'].sort(),
    )
    for (const a of mapped.assumed) {
      expect(a.note.length, a.field).toBeGreaterThan(10)
      // No note may quote a number — that is how an assumption becomes a claim.
      expect(a.note, a.field).not.toMatch(/\d/)
    }
  })

  it('widens the range when it knows less, rather than guessing', () => {
    const sparse = project(profileFromFirestore(tier0Only())!.profile, { now: NOW })
    const full = project(profile(), { now: NOW })
    const width = (r: { low: number; high: number }) => r.high - r.low
    expect(sparse.widened).toBe(true)
    expect(width(sparse.healthyYearsRange)).toBeGreaterThan(width(full.healthyYearsRange))
  })

  it('tells a cat owner we are using the reference, not a penalty', () => {
    const cat = profileFromFirestore(
      tier0Only({
        species: { value: 'cat', provenance: 'owner_declared', updatedAt: NOW.toISOString(), updatedBy: UID },
        breedId: { value: 'domestic-shorthair', provenance: 'owner_declared', updatedAt: NOW.toISOString(), updatedBy: UID },
      } as Partial<StoredPet>),
    )!
    const outdoor = cat.assumed.find((a) => a.field === 'outdoorAccess')
    expect(outdoor).toBeTruthy()
    expect(outdoor!.note).toMatch(/reference/i)
    // Dogs are never asked, so nothing is assumed about them.
    expect(profileFromFirestore(tier0Only())!.assumed.some((a) => a.field === 'outdoorAccess')).toBe(
      false,
    )
  })
})

describe('profileFromFirestore — untrusted input', () => {
  it('returns null rather than throwing on anything unusable', () => {
    const bad: unknown[] = [
      null,
      undefined,
      'nope',
      42,
      {},
      { id: 'x' },
      tier0Only({ breedId: { value: 'no-such-breed', provenance: 'owner_declared', updatedAt: NOW.toISOString(), updatedBy: UID } } as Partial<StoredPet>),
      tier0Only({ birthDate: { value: 'not-a-date', provenance: 'owner_declared', updatedAt: NOW.toISOString(), updatedBy: UID } } as Partial<StoredPet>),
      tier0Only({ name: { value: '   ', provenance: 'owner_declared', updatedAt: NOW.toISOString(), updatedBy: UID } } as Partial<StoredPet>),
      tier0Only({ species: { value: 'ferret', provenance: 'owner_declared', updatedAt: NOW.toISOString(), updatedBy: UID } } as unknown as Partial<StoredPet>),
    ]
    for (const b of bad) {
      expect(() => profileFromFirestore(b), JSON.stringify(b)?.slice(0, 60)).not.toThrow()
      expect(profileFromFirestore(b), JSON.stringify(b)?.slice(0, 60)).toBeNull()
    }
  })

  it('drops a malformed field rather than the whole pet', () => {
    // A bad weight written by an older build must cost the weight, not Scout.
    const mapped = profileFromFirestore(
      tier0Only({ weightLb: { value: 'heavy', provenance: 'owner_declared', updatedAt: NOW.toISOString(), updatedBy: UID } } as unknown as Partial<StoredPet>),
    )
    expect(mapped).not.toBeNull()
    expect(mapped!.profile.weightLb).toBe(0)
    expect(mapped!.assumed.some((a) => a.field === 'weightLb')).toBe(true)
  })

  it('rejects a field whose envelope is wrong, however plausible the value', () => {
    // A raw value with no provenance is not a Field. Accepting it would create
    // stored data with no answer to "who said this", breaking invariant 8.
    const mapped = profileFromFirestore(
      tier0Only({ activity: 'high' } as unknown as Partial<StoredPet>),
    )!
    expect(mapped.profile.activity).toBe('moderate')
    expect(mapped.assumed.some((a) => a.field === 'activity')).toBe(true)

    const badProv = profileFromFirestore(
      tier0Only({
        activity: { value: 'high', provenance: 'vibes', updatedAt: NOW.toISOString(), updatedBy: UID },
      } as unknown as Partial<StoredPet>),
    )!
    expect(badProv.profile.activity).toBe('moderate')
  })

  it('is pure — same input, same output', () => {
    const doc = tier0Only()
    expect(profileFromFirestore(doc)).toEqual(profileFromFirestore(doc))
  })
})
