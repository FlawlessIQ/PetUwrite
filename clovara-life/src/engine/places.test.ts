import { describe, expect, it } from 'vitest'
import { forEmergency, makeGooglePlacesProvider } from './places'
import type { EmergencyVet } from './toxins'

const vet = (over: Partial<EmergencyVet> = {}): EmergencyVet => ({
  name: 'Riverside Vets',
  address: '1 High Street',
  ...over,
})

describe('ordering for an emergency', () => {
  it('puts an open practice before a nearer closed one', () => {
    // Google ranks by distance and treats openNow as a field, not a sort. A
    // closed practice two streets away is worse than an open one twenty
    // minutes out, and at 2am that is the entire question.
    const out = forEmergency([
      vet({ name: 'Closed & near', openNow: false, distanceKm: 0.4 }),
      vet({ name: 'Open & far', openNow: true, distanceKm: 18 }),
    ])
    expect(out.map((v) => v.name)).toEqual(['Open & far', 'Closed & near'])
  })

  it('sorts unknown hours below confirmed-open and above confirmed-closed', () => {
    // "We do not know" is not "yes", and it is not "no" either.
    const out = forEmergency([
      vet({ name: 'closed', openNow: false, distanceKm: 1 }),
      vet({ name: 'unknown', openNow: undefined, distanceKm: 9 }),
      vet({ name: 'open', openNow: true, distanceKm: 20 }),
    ])
    expect(out.map((v) => v.name)).toEqual(['open', 'unknown', 'closed'])
  })

  it('breaks ties by distance', () => {
    const out = forEmergency([
      vet({ name: 'far', openNow: true, distanceKm: 12 }),
      vet({ name: 'near', openNow: true, distanceKm: 3 }),
    ])
    expect(out.map((v) => v.name)).toEqual(['near', 'far'])
  })

  it('does not mutate the input', () => {
    const list = [vet({ name: 'a', openNow: false }), vet({ name: 'b', openNow: true })]
    forEmergency(list)
    expect(list.map((v) => v.name)).toEqual(['a', 'b'])
  })

  it('handles missing distances without putting them first', () => {
    const out = forEmergency([vet({ name: 'nodist', openNow: true }), vet({ name: 'known', openNow: true, distanceKm: 5 })])
    expect(out[0].name).toBe('known')
  })
})

describe('the provider', () => {
  it('reports unavailable without a key rather than throwing', async () => {
    const p = makeGooglePlacesProvider('')
    expect(p.available).toBe(false)
    expect(await p.findEmergencyVets({ lat: 0, lng: 0 })).toEqual([])
  })

  it('asks for only the fields that help, because each one is billable', async () => {
    // No reviews, no photos, no editorial summary. None of them help at 2am and
    // all of them are a separate billing SKU.
    let captured: { url: string; headers: Record<string, string>; body: string } | null = null
    const realFetch = globalThis.fetch
    globalThis.fetch = (async (url: string, init: RequestInit) => {
      captured = { url: String(url), headers: init.headers as Record<string, string>, body: String(init.body) }
      return { ok: true, json: async () => ({ places: [] }) } as Response
    }) as typeof fetch

    await makeGooglePlacesProvider('test-key').findEmergencyVets({ lat: 51.5, lng: -0.12 })
    globalThis.fetch = realFetch

    const mask = captured!.headers['X-Goog-FieldMask']
    expect(mask).toContain('places.displayName')
    expect(mask).toContain('places.currentOpeningHours.openNow')
    for (const costly of ['reviews', 'photos', 'editorialSummary', 'priceLevel']) {
      expect(mask, costly).not.toContain(costly)
    }
  })

  it('asks for open emergency vets, nearest first, not "veterinary care"', async () => {
    // Tried against central London at 2am, includedTypes: ['veterinary_care']
    // returned a cattery, a telemedicine office and two closed daytime
    // practices — that type covers groomers and boarding, and openNow is a
    // field you read rather than a filter you apply.
    const bodies: Record<string, unknown>[] = []
    const realFetch = globalThis.fetch
    globalThis.fetch = (async (_u: string, init: RequestInit) => {
      bodies.push(JSON.parse(String(init.body)))
      return { ok: true, json: async () => ({ places: [{ displayName: { text: 'A' } }] }) } as Response
    }) as typeof fetch
    await makeGooglePlacesProvider('k').findEmergencyVets({ lat: 51.5, lng: -0.12 })
    globalThis.fetch = realFetch

    expect(bodies[0].textQuery).toBe('emergency vet')
    expect(bodies[0].openNow).toBe(true)
    expect(bodies[0].includedTypes).toBeUndefined()
    expect(bodies[0].rankPreference).toBe('DISTANCE')
    expect(bodies[0].maxResultCount).toBeLessThanOrEqual(5)
  })

  it('falls back to any hours when nothing is open, rather than an empty list', async () => {
    // At 2am an empty list reads as "there is nowhere", and a closed
    // practice's number is still a number worth having.
    const bodies: Record<string, unknown>[] = []
    const realFetch = globalThis.fetch
    globalThis.fetch = (async (_u: string, init: RequestInit) => {
      const b = JSON.parse(String(init.body))
      bodies.push(b)
      return {
        ok: true,
        json: async () => (b.openNow ? { places: [] } : { places: [{ displayName: { text: 'Closed but real' } }] }),
      } as Response
    }) as typeof fetch
    const out = await makeGooglePlacesProvider('k').findEmergencyVets({ lat: 51.5, lng: -0.12 })
    globalThis.fetch = realFetch

    expect(bodies).toHaveLength(2)
    expect(bodies[1].openNow).toBe(false)
    expect(out.map((v) => v.name)).toEqual(['Closed but real'])
  })

  it('does not make a second call when the first one found something', async () => {
    let calls = 0
    const realFetch = globalThis.fetch
    globalThis.fetch = (async () => {
      calls++
      return { ok: true, json: async () => ({ places: [{ displayName: { text: 'Open' } }] }) } as Response
    }) as typeof fetch
    await makeGooglePlacesProvider('k').findEmergencyVets({ lat: 1, lng: 2 })
    globalThis.fetch = realFetch
    expect(calls).toBe(1)
  })

  it('sends the key as a header, never in the URL', async () => {
    // A key in a query string ends up in logs, referrers and history.
    let cap: { url: string; headers: Record<string, string> } | null = null
    const realFetch = globalThis.fetch
    globalThis.fetch = (async (url: string, init: RequestInit) => {
      cap = { url: String(url), headers: init.headers as Record<string, string> }
      return { ok: true, json: async () => ({ places: [] }) } as Response
    }) as typeof fetch
    await makeGooglePlacesProvider('secret-key').findEmergencyVets({ lat: 1, lng: 2 })
    globalThis.fetch = realFetch

    expect(cap!.url).not.toContain('secret-key')
    expect(cap!.headers['X-Goog-Api-Key']).toBe('secret-key')
  })

  it('computes a plausible distance', async () => {
    const realFetch = globalThis.fetch
    globalThis.fetch = (async () =>
      ({
        ok: true,
        json: async () => ({
          places: [
            {
              displayName: { text: 'Near' },
              formattedAddress: 'x',
              location: { latitude: 51.51, longitude: -0.12 },
            },
          ],
        }),
      }) as Response) as typeof fetch
    const out = await makeGooglePlacesProvider('k').findEmergencyVets({ lat: 51.5, lng: -0.12 })
    globalThis.fetch = realFetch
    expect(out[0].distanceKm).toBeGreaterThan(0.5)
    expect(out[0].distanceKm).toBeLessThan(3)
  })
})
