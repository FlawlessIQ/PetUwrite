import { describe, expect, it } from 'vitest'
import { daysBetween, parseSource, sourceProps } from './source'

const NOW = new Date('2026-09-30T12:00:00Z')

describe('first touch', () => {
  it('reads utm tags off the landing URL', () => {
    const t = parseSource('https://clovara-life.web.app/?utm_source=shelter&utm_medium=card&utm_campaign=autumn', '', NOW)
    expect(t).toMatchObject({ utm_source: 'shelter', utm_medium: 'card', utm_campaign: 'autumn', referrer_host: null })
  })

  it('keeps only the referring HOST — a path can carry a search or a name', () => {
    const t = parseSource('https://clovara-life.web.app/', 'https://www.google.com/search?q=my+dog+bruno+limping', NOW)
    expect(t.referrer_host).toBe('www.google.com')
    expect(JSON.stringify(t)).not.toMatch(/bruno|limping|search/)
  })

  it('does not count our own site as a source', () => {
    expect(parseSource('https://clovara-life.web.app/#/pet/x/home', 'https://clovara-life.web.app/', NOW).referrer_host).toBeNull()
  })

  it('survives junk', () => {
    expect(parseSource('not a url', 'also not', NOW)).toMatchObject({ referrer_host: null, utm_source: null })
  })

  it('caps a tag rather than storing an essay', () => {
    const long = 'x'.repeat(500)
    expect(parseSource(`https://a.test/?utm_campaign=${long}`, '', NOW).utm_campaign).toHaveLength(60)
  })

  it('turns into flat event props, and nothing when there is no touch', () => {
    expect(sourceProps(null)).toEqual({})
    expect(Object.keys(sourceProps(parseSource('https://a.test/', '', NOW))).sort()).toEqual(['referrer_host', 'utm_campaign', 'utm_medium', 'utm_source'])
  })
})

describe('days since the first visit', () => {
  it('counts whole days and never goes negative', () => {
    expect(daysBetween('2026-09-23T12:00:00Z', NOW)).toBe(7)
    expect(daysBetween('2026-10-05T12:00:00Z', NOW)).toBe(0)
    expect(daysBetween('garbage', NOW)).toBe(0)
  })
})
