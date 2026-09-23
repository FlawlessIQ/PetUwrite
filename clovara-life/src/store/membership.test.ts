import { describe, expect, it } from 'vitest'
import { entitlementFrom, isMember, NO_ENTITLEMENT, trialDaysLeft } from './membership'

const NOW = new Date('2026-09-23T12:00:00Z')
const ent = (over: Partial<ReturnType<typeof entitlementFrom>> = {}) => ({
  ...NO_ENTITLEMENT,
  ...over,
})

describe('isMember', () => {
  it('unlocks for trialing and active', () => {
    expect(isMember(ent({ status: 'trialing' }))).toBe(true)
    expect(isMember(ent({ status: 'active' }))).toBe(true)
  })

  it('keeps past_due unlocked', () => {
    // Someone whose card failed this morning has not stopped being a customer.
    // Locking them out is how a recoverable payment problem becomes a
    // cancellation — Stripe's dunning gets its chance first, and the webhook
    // moves them to canceled if it runs out.
    expect(isMember(ent({ status: 'past_due' }))).toBe(true)
  })

  it('locks for everything else, including nothing at all', () => {
    for (const status of ['none', 'canceled', 'incomplete', 'unpaid'] as const) {
      expect(isMember(ent({ status })), status).toBe(false)
    }
    expect(isMember(null)).toBe(false)
    expect(isMember(undefined)).toBe(false)
  })
})

describe('trialDaysLeft', () => {
  it('counts whole days remaining, rounding up', () => {
    const e = ent({ status: 'trialing', trialEnd: '2026-09-26T12:00:00Z' })
    expect(trialDaysLeft(e, NOW)).toBe(3)
    expect(trialDaysLeft(ent({ status: 'trialing', trialEnd: '2026-09-23T18:00:00Z' }), NOW)).toBe(1)
  })

  it('never goes negative once the trial has passed', () => {
    expect(trialDaysLeft(ent({ status: 'trialing', trialEnd: '2026-09-01T12:00:00Z' }), NOW)).toBe(0)
  })

  it('is null when there is no trial to count', () => {
    expect(trialDaysLeft(ent({ status: 'active', trialEnd: '2026-09-26T12:00:00Z' }), NOW)).toBeNull()
    expect(trialDaysLeft(ent({ status: 'trialing', trialEnd: null }), NOW)).toBeNull()
    expect(trialDaysLeft(ent({ status: 'trialing', trialEnd: 'not a date' }), NOW)).toBeNull()
    expect(trialDaysLeft(null, NOW)).toBeNull()
  })
})

describe('entitlementFrom', () => {
  it('reads what the webhook writes', () => {
    expect(
      entitlementFrom({
        status: 'trialing',
        trialEnd: '2026-09-30T00:00:00Z',
        currentPeriodEnd: '2026-10-30T00:00:00Z',
        cancelAtPeriodEnd: false,
        priceId: 'price_123',
        stripeCustomerId: 'cus_123',
      }),
    ).toEqual({
      status: 'trialing',
      trialEnd: '2026-09-30T00:00:00Z',
      currentPeriodEnd: '2026-10-30T00:00:00Z',
      cancelAtPeriodEnd: false,
      priceId: 'price_123',
    })
  })

  it('falls back to locked for anything it does not recognise', () => {
    // A status we cannot read must never accidentally unlock member surfaces.
    for (const bad of [null, undefined, 'nope', 42, {}, { status: 'vip' }, { status: 123 }]) {
      expect(isMember(entitlementFrom(bad)), JSON.stringify(bad)).toBe(false)
    }
    expect(entitlementFrom({ status: 'vip' }).status).toBe('none')
  })

  it('does not treat a truthy non-boolean as cancelled-at-period-end', () => {
    expect(entitlementFrom({ status: 'active', cancelAtPeriodEnd: 'yes' }).cancelAtPeriodEnd).toBe(
      false,
    )
  })
})
