import { describe, expect, it } from 'vitest'
import { afterFlush, dedupe, enqueue, MAX_QUEUED, parseQueue, prepareFlush } from './queue'
import { EVENT_NAMES, makeEvent, sanitizeProps, type AnalyticsEvent } from './events'

const CTX = { visitorId: 'v1', sessionId: 's1', build: 'test', now: new Date('2026-09-23T12:00:00Z') }
const ev = (over: Partial<AnalyticsEvent> = {}): AnalyticsEvent => ({
  ...makeEvent('reveal_viewed', {}, CTX),
  ...over,
})

describe('makeEvent / sanitizeProps', () => {
  it('keeps the four simple types and drops everything else', () => {
    const out = sanitizeProps({
      a_string: 'ok',
      a_number: 42,
      a_bool: true,
      a_null: null,
      // @ts-expect-error deliberately wrong at runtime
      an_object: { nested: 'no' },
      // @ts-expect-error deliberately wrong at runtime
      an_array: [1, 2],
      // @ts-expect-error deliberately wrong at runtime
      undef: undefined,
    })
    expect(out).toEqual({ a_string: 'ok', a_number: 42, a_bool: true, a_null: null })
  })

  it('refuses keys that are not plain snake_case identifiers', () => {
    const out = sanitizeProps({
      good_key: 1,
      // @ts-expect-error runtime-only keys
      'bad-key': 1,
      // @ts-expect-error runtime-only keys
      'Bad': 1,
      // @ts-expect-error runtime-only keys
      '': 1,
    })
    expect(Object.keys(out)).toEqual(['good_key'])
  })

  it('truncates long strings rather than storing them whole', () => {
    // Analytics is the easiest place to accidentally start storing personal
    // data. A 10KB free-text field must not land in the events collection.
    const out = sanitizeProps({ note: 'x'.repeat(5000) })
    expect((out.note as string).length).toBe(120)
  })

  it('coerces non-finite numbers to null instead of writing NaN', () => {
    expect(sanitizeProps({ n: NaN, i: Infinity })).toEqual({ n: null, i: null })
  })

  it('stamps every event with what is needed to join it to an account later', () => {
    const e = makeEvent('reveal_viewed', { surface: 'life' }, CTX)
    expect(e).toMatchObject({
      name: 'reveal_viewed',
      visitorId: 'v1',
      sessionId: 's1',
      build: 'test',
      uid: null,
      at: '2026-09-23T12:00:00.000Z',
    })
  })

  it('covers every gate SPEC §3 names', () => {
    for (const required of [
      'reveal_viewed',
      'trial_started',
      'tier1_field_added',
      'accuracy_score',
      'records_connected',
      'attach_offer_viewed',
      'attach_bound',
      'week4_active',
    ]) {
      expect(EVENT_NAMES, required).toContain(required)
    }
  })
})

describe('enqueue', () => {
  it('appends in order below the cap', () => {
    let q: AnalyticsEvent[] = []
    for (const name of ['reveal_viewed', 'signed_up', 'trial_started'] as const) {
      q = enqueue(q, ev({ name })).queue
    }
    expect(q.map((e) => e.name)).toEqual(['reveal_viewed', 'signed_up', 'trial_started'])
  })

  it('drops the OLDEST when over the cap, and says how many', () => {
    // A browser left open on a flaky connection must not grow an unbounded
    // localStorage entry — it shares storage with the pets.
    let q: AnalyticsEvent[] = []
    for (let i = 0; i < 5; i++) q = enqueue(q, ev({ at: `t${i}` }), 3).queue
    expect(q.map((e) => e.at)).toEqual(['t2', 't3', 't4'])
    expect(enqueue(q, ev({ at: 't5' }), 3).dropped).toBe(1)
  })

  it('has a cap that is actually finite', () => {
    expect(MAX_QUEUED).toBeGreaterThan(0)
    expect(Number.isFinite(MAX_QUEUED)).toBe(true)
  })
})

describe('prepareFlush', () => {
  it('stamps the uid the rules will check against', () => {
    // life_events requires request.resource.data.uid == request.auth.uid, so an
    // event flushed under the wrong identity is rejected outright.
    const out = prepareFlush([ev(), ev({ name: 'trial_started' })], 'uid-9')
    expect(out.every((e) => e.uid === 'uid-9')).toBe(true)
  })

  it('does not mutate the queue it was given', () => {
    const q = [ev()]
    prepareFlush(q, 'uid-9')
    expect(q[0].uid).toBeNull()
  })
})

describe('afterFlush', () => {
  it('keeps events that arrived during the flight', () => {
    // A flush taking two seconds must not discard what was logged in them.
    const sent = [ev({ at: 't1' }), ev({ at: 't2' })]
    const during = ev({ at: 't3', name: 'pet_created' })
    expect(afterFlush([...sent, during], sent)).toEqual([during])
  })

  it('is a no-op when nothing was sent', () => {
    const q = [ev()]
    expect(afterFlush(q, [])).toBe(q)
  })

  it('distinguishes two different events sharing a millisecond', () => {
    const a = ev({ at: 't1', name: 'reveal_viewed' })
    const b = ev({ at: 't1', name: 'signed_up' })
    expect(afterFlush([a, b], [a])).toEqual([b])
  })
})

describe('dedupe', () => {
  it('removes exact duplicates a retried flush can create', () => {
    const a = ev({ at: 't1' })
    expect(dedupe([a, { ...a }, ev({ at: 't2' })])).toHaveLength(2)
  })
})

describe('parseQueue', () => {
  it('reads back what was written', () => {
    const q = [ev(), ev({ name: 'trial_started' })]
    expect(parseQueue(JSON.stringify(q))).toEqual(q)
  })

  it('returns an empty queue for anything unusable, rather than throwing', () => {
    for (const bad of [null, undefined, 42, '', 'not json', '{}', '[1,2,3]', '"a"']) {
      expect(() => parseQueue(bad), String(bad)).not.toThrow()
      expect(parseQueue(bad), String(bad)).toEqual([])
    }
  })

  it('drops malformed entries but keeps the good ones beside them', () => {
    const good = ev()
    const raw = JSON.stringify([good, { name: 'x' }, null, 'nope'])
    expect(parseQueue(raw)).toEqual([good])
  })

  it('never returns more than the cap, however large the stored array', () => {
    const raw = JSON.stringify(Array.from({ length: MAX_QUEUED + 50 }, (_, i) => ev({ at: `t${i}` })))
    expect(parseQueue(raw)).toHaveLength(MAX_QUEUED)
  })
})
