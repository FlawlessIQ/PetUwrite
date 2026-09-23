import { describe, expect, it } from 'vitest'
import {
  MockRatingAdapter,
  datedWaiting,
  earliestEffective,
  noPreExistingLine,
  preExistingPicture,
  ratingAdapter,
  setRatingAdapter,
  type RatingAdapter,
} from './attach'
import {
  ATTESTATION,
  DISCLOSURES,
  FRAUD_NOTICE,
  ILLUSTRATIVE_LABEL,
  REVERSE_BRIDGE_ENABLED,
  REVERSE_BRIDGE_VAS_FREE_MONTHS_ENABLED,
  WAITING_PERIODS,
} from '../data/attach'
import { project } from './project'
import type { PetProfile } from '../data/types'

const NOW = new Date('2026-09-23T12:00:00Z')
const pet = (over: Partial<PetProfile> = {}): PetProfile => ({
  id: 'p',
  name: 'Scout',
  species: 'dog',
  breedId: 'labrador-retriever',
  birthDate: '2021-04-02',
  sex: 'female',
  weightLb: 68,
  conditionIds: [],
  ...over,
})
const proj = (p: PetProfile) => project(p, { now: NOW })

describe('the rating adapter', () => {
  it('starts on the mock, which cannot bind', () => {
    // SPEC §5: real binding is gated on the carrier programme and is NOT this
    // phase's dependency.
    expect(ratingAdapter().id).toBe('mock')
    expect(MockRatingAdapter.canBind).toBe(false)
  })

  it('marks every mock quote illustrative, which the UI must label', () => {
    const p = pet()
    const q = MockRatingAdapter.quote(p, proj(p), { tierId: 'complete', rider: false })
    expect(q.illustrative).toBe(true)
    expect(ILLUSTRATIVE_LABEL).toMatch(/not yet filed/i)
    expect(ILLUSTRATIVE_LABEL).toMatch(/not an offer/i)
  })

  it('keeps the rider as a separate line, never folded into the premium', () => {
    // Invariant 2: premiums separate and labelled, in UI, Stripe and receipts.
    const p = pet()
    const withRider = MockRatingAdapter.quote(p, proj(p), { tierId: 'complete', rider: true })
    const without = MockRatingAdapter.quote(p, proj(p), { tierId: 'complete', rider: false })
    expect(withRider.monthlyPremium).toBe(without.monthlyPremium)
    expect(withRider.riderPrice).toBeGreaterThan(0)
    expect(without.riderPrice).toBe(0)
    expect(withRider.totalMonthly).toBeCloseTo(withRider.monthlyPremium + withRider.riderPrice, 2)
  })

  it('shows every factor rather than a single number', () => {
    const p = pet()
    const q = MockRatingAdapter.quote(p, proj(p), { tierId: 'complete', rider: false })
    expect(q.breakdown.length).toBeGreaterThan(2)
    expect(q.breakdown.every((b) => b.note.length > 10)).toBe(true)
  })

  it('offers a smart default with no form, per SPEC §5', () => {
    const young = pet({ birthDate: '2024-04-02' })
    const old = pet({ birthDate: '2014-04-02' })
    expect(MockRatingAdapter.smartDefault(young, proj(young)).tierId).toBe('complete')
    // The rider covers routine care, so it defaults on only while that care is
    // still ahead of them.
    expect(MockRatingAdapter.smartDefault(young, proj(young)).rider).toBe(true)
    expect(MockRatingAdapter.smartDefault(old, proj(old)).rider).toBe(false)
  })

  it('refuses to bind, and says why rather than failing silently', async () => {
    const r = await MockRatingAdapter.bind({
      petId: 'p',
      tierId: 'complete',
      rider: false,
      effectiveDate: '2026-09-24',
    })
    expect(r.ok).toBe(false)
    expect(r.policyNumber).toBeNull()
    expect(r.unavailableReason).toMatch(/carrier programme/i)
  })

  it('swaps for a real carrier adapter without a surface knowing', () => {
    const real: RatingAdapter = {
      id: 'accelerant',
      canBind: true,
      quote: (p, pr, o) => ({ ...MockRatingAdapter.quote(p, pr, o), illustrative: false, adapterId: 'accelerant' }),
      smartDefault: MockRatingAdapter.smartDefault,
      bind: async () => ({ ok: true, policyNumber: 'CL-1', effectiveDate: '2026-09-24' }),
    }
    setRatingAdapter(real)
    const p = pet()
    expect(ratingAdapter().quote(p, proj(p), { tierId: 'complete', rider: false }).illustrative).toBe(
      false,
    )
    setRatingAdapter(MockRatingAdapter)
  })
})

describe('the screen of truth', () => {
  it('gives waiting periods as dates, not durations', () => {
    // SPEC §5: "waiting periods as dated countdowns". "14 days" needs arithmetic
    // at the moment somebody is deciding; a date does not.
    const effective = new Date('2026-10-01T00:00:00Z')
    const w = datedWaiting(effective)
    const illness = w.find((x) => x.id === 'illness')!
    expect(illness.coveredFrom.toISOString().slice(0, 10)).toBe('2026-10-15')
    expect(w.every((x) => x.coveredFrom.getTime() >= effective.getTime())).toBe(true)
  })

  it('surfaces the orthopaedic wait, which is the one that catches people', () => {
    const ortho = WAITING_PERIODS.find((w) => w.id === 'orthopaedic')!
    expect(ortho.days).toBeGreaterThanOrEqual(120)
    expect(ortho.because).toMatch(/before you need it/i)
  })

  it('names every pre-existing condition in plain words', () => {
    const lines = preExistingPicture(pet({ conditionIds: ['hip-dysplasia'] }))
    expect(lines).toHaveLength(1)
    expect(lines[0].meaning).toMatch(/will not be covered/i)
    expect(lines[0].meaning).toMatch(/Everything unrelated still is/i)
    expect(lines[0].meaning).toContain('Scout')
  })

  it('says so explicitly when there is nothing to exclude', () => {
    // A blank space reads as "nothing is excluded", which is a promise about
    // the future that nobody can make.
    const line = noPreExistingLine(pet())
    expect(line).toMatch(/nothing is excluded as pre-existing today/i)
    expect(line).toMatch(/before .* cover starts, it would be/i)
  })

  it('never starts a policy the same day', () => {
    const e = earliestEffective(NOW)
    expect(e.getTime()).toBeGreaterThan(NOW.getTime())
    expect(e.toISOString().slice(0, 10)).toBe('2026-09-24')
  })
})

describe('the disclosures', () => {
  it('leads the pre-existing disclosure, because it is the commonest decline', () => {
    expect(DISCLOSURES[0].id).toBe('pre-existing')
    expect(DISCLOSURES[0].body).toMatch(/most common reason a claim is declined/i)
  })

  it('states insurance is separate from membership and points never reduce it', () => {
    // Invariants 1 and 2.
    const sep = DISCLOSURES.find((d) => d.id === 'separate')!
    expect(sep.body).toMatch(/two different lines/i)
    expect(sep.body).toMatch(/points never reduce a premium/i)
  })

  it('promises at renewal what the Data Covenant promised', () => {
    const r = DISCLOSURES.find((d) => d.id === 'renewal')!
    expect(r.body).toMatch(/never anything measured by a tracker or said to the companion/i)
  })

  it('carries a fraud notice and an attestation', () => {
    expect(FRAUD_NOTICE).toMatch(/fraudulent insurance act/i)
    expect(FRAUD_NOTICE).toMatch(/state-specific wording will replace/i)
    expect(ATTESTATION).toMatch(/accurate as far as I know/i)
  })

  it('keeps the reverse bridge and its free-months variant off', () => {
    // Free months as an inducement to buy insurance is a rebating question in
    // several states, not a marketing decision.
    expect(REVERSE_BRIDGE_ENABLED).toBe(false)
    expect(REVERSE_BRIDGE_VAS_FREE_MONTHS_ENABLED).toBe(false)
  })
})
