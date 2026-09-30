import { describe, expect, it } from 'vitest'
import { cardContentFromLink, cardLink, parseCardLink } from './cardLink'

const ORIGIN = 'https://clovara-life.web.app'
const hashOf = (url: string) => url.slice(url.indexOf('#'))
const arrival = { kind: 'arrival' as const, name: 'Bruno', breedName: 'Labrador Retriever', ageLabel: '2 months old', date: '2026-09-30' }

describe('the card link', () => {
  it('round-trips, and redraws the same words the card had', () => {
    const f = parseCardLink(hashOf(cardLink(ORIGIN, arrival)))
    expect(f).toEqual(arrival)
    const c = cardContentFromLink(f!)
    expect(c.headline).toBe('Bruno’s plan begins today.')
    expect(c.subtitle).toBe('Labrador Retriever · 2 months old')
    expect(c.footnote).toBe('30 September 2026')
  })

  it('carries a Gotcha Day with its years', () => {
    const g = { ...arrival, kind: 'gotcha' as const, ageLabel: '4 years old', years: 3 }
    const f = parseCardLink(hashOf(cardLink(ORIGIN, g)))
    expect(f?.years).toBe(3)
    expect(cardContentFromLink(f!).headline).toBe('3 years home.')
  })

  it('carries nothing but what is printed on the card — never a photo or an id', () => {
    const url = cardLink(ORIGIN, { ...arrival, ...({ photoUrl: 'https://x/p.jpg', id: 'pet-1', householdId: 'h1' } as object) })
    expect(url).not.toMatch(/photo|pet-1|h1|householdId/)
    expect(cardContentFromLink(parseCardLink(hashOf(url))!).photoUrl).toBeUndefined()
    expect([...new URLSearchParams(url.split('?')[1]).keys()].sort()).toEqual(['a', 'b', 'd', 'k', 'n'])
  })

  it('survives apostrophes, accents and spaces in a name', () => {
    const f = parseCardLink(hashOf(cardLink(ORIGIN, { ...arrival, name: 'Señor Biscuit O’Neill' })))
    expect(f?.name).toBe('Señor Biscuit O’Neill')
  })

  it('refuses anything incomplete or odd, rather than drawing a card with holes', () => {
    expect(parseCardLink('#/card?k=arrival&n=Bruno')).toBeNull()
    expect(parseCardLink('#/card?k=trophy&n=B&b=L&a=1&d=2026-09-30')).toBeNull()
    expect(parseCardLink('#/card?k=arrival&n=B&b=L&a=1&d=yesterday')).toBeNull()
    expect(parseCardLink('#/card?k=gotcha&n=B&b=L&a=1&d=2026-09-30&y=0')).toBeNull()
    expect(parseCardLink('#/card?k=gotcha&n=B&b=L&a=1&d=2026-09-30&y=99')).toBeNull()
    expect(parseCardLink('#/pet/x/home')).toBeNull()
  })

  it('caps long fields and strips control characters', () => {
    const f = parseCardLink(`#/card?k=arrival&n=${'x'.repeat(200)}%0A&b=L&a=1&d=2026-09-30`)
    expect(f?.name).toHaveLength(40)
    expect(f?.name).not.toMatch(/\n/)
  })
})
