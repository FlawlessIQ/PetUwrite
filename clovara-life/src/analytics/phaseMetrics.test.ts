import { describe, expect, it } from 'vitest'
import {
  accuracyDistribution,
  median,
  percentile,
  recordsByDay30,
  tier1Completion,
  timeToReveal,
} from './phaseMetrics'
import type { AnalyticsEvent, EventName, EventProps } from './events'

const NOW = new Date('2026-09-23T12:00:00Z')
const at = (daysAgo: number) => new Date(NOW.getTime() - daysAgo * 86_400_000).toISOString()

let n = 0
function ev(
  name: EventName,
  over: { visitor?: string; session?: string; props?: EventProps; at?: string } = {},
): AnalyticsEvent {
  n++
  return {
    name,
    props: over.props ?? {},
    at: over.at ?? at(0),
    visitorId: over.visitor ?? `v${n}`,
    uid: null,
    sessionId: over.session ?? `s${n}`,
    build: 'test',
  }
}

describe('median and percentile', () => {
  it('handles an empty list without returning NaN', () => {
    expect(median([])).toBeNull()
    expect(percentile([], 90)).toBeNull()
  })

  it('averages the middle pair on an even-length list', () => {
    expect(median([1, 2, 3, 4])).toBe(2.5)
    expect(median([3, 1])).toBe(2)
  })

  it('does not depend on input order', () => {
    expect(median([9, 1, 5])).toBe(5)
    expect(percentile([100, 1, 50, 2], 50)).toBe(2)
  })

  it('never reads off the end of the list', () => {
    expect(percentile([1, 2, 3], 100)).toBe(3)
    expect(percentile([1, 2, 3], 0)).toBe(1)
  })
})

describe('time to reveal', () => {
  it('reports median and p90 in seconds', () => {
    const events = [10_000, 20_000, 30_000, 120_000].map((ms) =>
      ev('reveal_viewed', { props: { ms_to_reveal: ms, pet_is_demo: false } }),
    )
    const t = timeToReveal(events)
    expect(t.samples).toBe(4)
    expect(t.medianSeconds).toBe(25)
    expect(t.p90Seconds).toBe(120)
    expect(t.withinTarget).toBe(3)
  })

  it('ignores reveals with no timing — a returning user is not an onboarding', () => {
    // Opening the app to a pet you already own reaches the reveal in a second
    // and a half. Counting it would report a wonderful number about nothing.
    const t = timeToReveal([
      ev('reveal_viewed', { props: { pet_is_demo: false } }),
      ev('reveal_viewed', { props: { ms_to_reveal: 40_000, pet_is_demo: false } }),
    ])
    expect(t.samples).toBe(1)
    expect(t.medianSeconds).toBe(40)
  })

  it('excludes the demo pets shown to investors', () => {
    const t = timeToReveal([
      ev('reveal_viewed', { props: { ms_to_reveal: 1_000, pet_is_demo: true } }),
      ev('reveal_viewed', { props: { ms_to_reveal: 45_000, pet_is_demo: false } }),
    ])
    expect(t.samples).toBe(1)
    expect(t.medianSeconds).toBe(45)
  })

  it('is empty rather than wrong when nothing has been measured', () => {
    expect(timeToReveal([])).toEqual({
      medianSeconds: null,
      p90Seconds: null,
      samples: 0,
      withinTarget: 0,
    })
  })
})

describe('tier-1 completion in the first session', () => {
  it('counts a session that answered nothing, rather than dropping it', () => {
    // The load-bearing case. If a session with no answers vanishes from the
    // denominator the rate is always 100% and the metric is decoration.
    const c = tier1Completion([
      ev('pet_created', { session: 'a', props: { pet_is_demo: false } }),
      ev('pet_created', { session: 'b', props: { pet_is_demo: false } }),
      ev('tier1_field_added', { session: 'a', props: { field: 'weightLb', pet_is_demo: false } }),
    ])
    expect(c.sessions).toBe(2)
    expect(c.completedAny).toBe(1)
    expect(c.rate).toBe(0.5)
  })

  it('counts distinct fields, not taps', () => {
    // Changing a mis-tapped silhouette fires again; it is not a second field.
    const c = tier1Completion([
      ev('pet_created', { session: 'a', props: { pet_is_demo: false } }),
      ev('tier1_field_added', { session: 'a', props: { field: 'weightLb', pet_is_demo: false } }),
      ev('tier1_field_added', { session: 'a', props: { field: 'weightLb', pet_is_demo: false } }),
      ev('tier1_field_added', { session: 'a', props: { field: 'neutered', pet_is_demo: false } }),
    ])
    expect(c.meanFields).toBe(2)
  })

  it('ignores sharpening done in a later session', () => {
    // "In the first session" is the metric. Answering a week later is good for
    // the pet and not what this number is asking.
    const c = tier1Completion([
      ev('pet_created', { session: 'a', props: { pet_is_demo: false } }),
      ev('tier1_field_added', { session: 'later', props: { field: 'dental', pet_is_demo: false } }),
    ])
    expect(c.completedAny).toBe(0)
    expect(c.rate).toBe(0)
  })

  it('excludes demo pets from both halves', () => {
    const c = tier1Completion([
      ev('pet_created', { session: 'demo', props: { pet_is_demo: true } }),
      ev('tier1_field_added', { session: 'demo', props: { field: 'weightLb', pet_is_demo: true } }),
      ev('pet_created', { session: 'real', props: { pet_is_demo: false } }),
    ])
    expect(c.sessions).toBe(1)
    expect(c.completedAny).toBe(0)
  })

  it('returns null rather than 0 when nobody has onboarded', () => {
    // Zero percent and "no data yet" are different, and one of them is alarming.
    expect(tier1Completion([]).rate).toBeNull()
  })
})

describe('accuracy distribution', () => {
  it('keeps one score per visitor — their best', () => {
    const d = accuracyDistribution([
      ev('accuracy_score', { visitor: 'v1', props: { score: 42, pet_is_demo: false } }),
      ev('accuracy_score', { visitor: 'v1', props: { score: 78, pet_is_demo: false } }),
      ev('accuracy_score', { visitor: 'v2', props: { score: 55, pet_is_demo: false } }),
    ])
    expect(d.visitors).toBe(2)
    expect(d.medianScore).toBe(66.5)
    expect(d.bands.find((b) => b.label === '60–79')!.count).toBe(1)
    expect(d.bands.find((b) => b.label === '40–59')!.count).toBe(1)
    expect(d.bands.find((b) => b.label === 'under 40')!.count).toBe(0)
  })

  it('places boundary scores in exactly one band', () => {
    const scores = [0, 39, 40, 59, 60, 79, 80, 89, 90, 94]
    const d = accuracyDistribution(
      scores.map((score, i) => ev('accuracy_score', { visitor: `v${i}`, props: { score, pet_is_demo: false } })),
    )
    expect(d.bands.reduce((a, b) => a + b.count, 0)).toBe(scores.length)
    expect(d.bands.map((b) => b.count)).toEqual([2, 2, 2, 2, 2])
  })

  it('drops scores that are not numbers rather than counting them as zero', () => {
    const d = accuracyDistribution([
      ev('accuracy_score', { visitor: 'v1', props: { score: null, pet_is_demo: false } }),
      ev('accuracy_score', { visitor: 'v2', props: { pet_is_demo: false } }),
    ])
    expect(d.visitors).toBe(0)
    expect(d.medianScore).toBeNull()
  })

  it('excludes demo pets', () => {
    const d = accuracyDistribution([
      ev('accuracy_score', { visitor: 'd', props: { score: 94, pet_is_demo: true } }),
    ])
    expect(d.visitors).toBe(0)
  })
})

describe('records connected by day 30', () => {
  it('only counts visitors old enough to have answered', () => {
    const d = recordsByDay30(
      [
        ev('session_start', { visitor: 'old', at: at(40) }),
        ev('records_connected', { visitor: 'old', at: at(35) }),
        ev('session_start', { visitor: 'new', at: at(2) }),
      ],
      NOW,
    )
    expect(d.eligible).toBe(1)
    expect(d.connected).toBe(1)
    expect(d.rate).toBe(1)
  })

  it('does not count a connection made after day 30', () => {
    const d = recordsByDay30(
      [
        ev('session_start', { visitor: 'late', at: at(90) }),
        ev('records_connected', { visitor: 'late', at: at(10) }), // day 80
      ],
      NOW,
    )
    expect(d.eligible).toBe(1)
    expect(d.connected).toBe(0)
  })

  it('is null, not zero, before anyone is thirty days old', () => {
    const d = recordsByDay30([ev('session_start', { visitor: 'new', at: at(3) })], NOW)
    expect(d.eligible).toBe(0)
    expect(d.rate).toBeNull()
  })
})
