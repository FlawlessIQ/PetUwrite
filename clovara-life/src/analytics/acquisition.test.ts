import { describe, expect, it } from 'vitest'
import { campaignLink, funnelBySource, returnRates, sourceOf, tagValue } from './acquisition'
import type { AnalyticsEvent, EventName, EventProps } from './events'

const NOW = new Date('2026-09-30T12:00:00Z')
const at = (daysAgo: number) => new Date(NOW.getTime() - daysAgo * 86_400_000).toISOString()

function ev(name: EventName, visitor: string, props: EventProps = {}, when = at(0)): AnalyticsEvent {
  return { name, props, at: when, visitorId: visitor, uid: null, sessionId: 's', build: 'test' }
}

describe('sourceOf', () => {
  it('prefers the utm tag, then the referring site, then direct', () => {
    expect(sourceOf(ev('first_visit', 'a', { utm_source: 'Rescue-Co', referrer_host: 'x.com' }))).toBe('rescue-co')
    expect(sourceOf(ev('first_visit', 'a', { utm_source: null, referrer_host: 'www.reddit.com' }))).toBe('reddit.com')
    expect(sourceOf(ev('first_visit', 'a', { utm_source: '  ', referrer_host: null }))).toBe('direct')
  })
})

describe('funnelBySource', () => {
  const steps: EventName[] = ['first_visit', 'reveal_viewed', 'signed_up']

  it('counts each step per source, a visitor once per step', () => {
    const rows = funnelBySource(
      [
        ev('first_visit', 'a', { utm_source: 'rescue' }),
        ev('reveal_viewed', 'a'),
        ev('reveal_viewed', 'a'),
        ev('signed_up', 'a'),
        ev('first_visit', 'b', { utm_source: 'rescue' }),
        ev('reveal_viewed', 'b'),
        ev('first_visit', 'c'),
      ],
      steps,
    )
    expect(rows).toEqual([
      { source: 'rescue', counts: [2, 2, 1] },
      { source: 'direct', counts: [1, 0, 0] },
    ])
  })

  it('files a visitor under their earliest first visit', () => {
    const rows = funnelBySource(
      [
        ev('first_visit', 'a', { utm_source: 'later' }, at(1)),
        ev('first_visit', 'a', { utm_source: 'earlier' }, at(3)),
      ],
      steps,
    )
    expect(rows.map((r) => r.source)).toEqual(['earlier'])
  })

  it('leaves out visitors with no first visit rather than guessing', () => {
    expect(funnelBySource([ev('reveal_viewed', 'z')], steps)).toEqual([])
  })

  it('sums the long tail into one row', () => {
    const events = ['a', 'b', 'c', 'd'].flatMap((s, i) =>
      Array.from({ length: 4 - i }, (_, j) => ev('first_visit', `${s}${j}`, { utm_source: s })),
    )
    const rows = funnelBySource(events, steps, 3)
    expect(rows.map((r) => r.source)).toEqual(['a', 'b', 'everything else (2)'])
    expect(rows[2].counts[0]).toBe(3)
  })
})

describe('returnRates', () => {
  it('counts only visitors old enough to have come back', () => {
    const rates = returnRates(
      [
        ev('first_visit', 'old', {}, at(30)),
        ev('return_visit', 'old', { days_since_first: 8 }, at(22)),
        ev('first_visit', 'week', {}, at(8)),
        ev('return_visit', 'week', { days_since_first: 1 }, at(7)),
        ev('first_visit', 'new', {}, at(0.5)),
      ],
      NOW,
    )
    expect(rates).toEqual([
      { day: 1, eligible: 2, returned: 2 },
      { day: 7, eligible: 2, returned: 1 },
      { day: 28, eligible: 1, returned: 0 },
    ])
  })
})

describe('campaign links', () => {
  it('tags a link to the front door', () => {
    expect(
      campaignLink('https://clovara-life.web.app/', {
        source: 'Happy Tails Rescue',
        medium: 'partner',
        campaign: 'Adoption pack — Oct',
      }),
    ).toBe(
      'https://clovara-life.web.app/?utm_source=happy-tails-rescue&utm_medium=partner&utm_campaign=adoption-pack-oct',
    )
  })

  it('needs a source, and leaves out empty tags', () => {
    expect(campaignLink('https://x.test', { source: ' ', medium: 'social', campaign: '' })).toBeNull()
    expect(campaignLink('https://x.test', { source: 'ig', medium: '', campaign: '' })).toBe(
      'https://x.test/?utm_source=ig',
    )
  })

  it('keeps tags readable and short', () => {
    expect(tagValue('  A  B!!  ')).toBe('a-b')
    expect(tagValue('x'.repeat(80))).toHaveLength(60)
  })
})
