import { describe, expect, it } from 'vitest'
import { COVENANT, COVENANT_INTRO, COVENANT_TEASER, COVENANT_TITLE } from './covenant'

const all = [
  COVENANT_TITLE,
  COVENANT_INTRO,
  COVENANT_TEASER,
  ...COVENANT.flatMap((s) => [s.heading, ...s.body, ...(s.promises ?? [])]),
].join('\n')

describe('the Data Covenant says what invariant 5 requires', () => {
  it('promises companion data is never used against a claim', () => {
    expect(all).toMatch(/companion[\s\S]{0,80}claim|claim[\s\S]{0,80}companion/i)
    expect(all).toMatch(/not to question one, not to delay one, not to deny one/i)
  })

  it('promises tracker data is never used against a claim', () => {
    expect(all).toMatch(/tracker records is used to decide a claim/i)
  })

  it('promises data does not change an individual premium', () => {
    expect(all).toMatch(/does not change your premium/i)
  })

  it('refuses the reward framing as explicitly as the penalty framing', () => {
    // A "discount for good behaviour" is the same mechanism wearing a smile,
    // and it is the one a product like this drifts into. The copy has to close
    // it by name or the promise above is only half made.
    expect(all).toMatch(/not down as a reward/i)
  })

  it('states the companion is firewalled from underwriting and claims', () => {
    // Invariant 4.
    expect(all).toMatch(/firewalled/i)
    expect(all).toMatch(/does not diagnose/i)
    expect(all).toMatch(/underwriting/i)
  })

  it('names the filed-programme exception rather than hiding it', () => {
    // Invariant 5 allows a filed, transparent programme. A covenant that did
    // not mention it would be a promise we already know we might break.
    const exception = COVENANT.find((s) => s.id === 'exception')
    expect(exception).toBeTruthy()
    const text = exception!.body.join(' ')
    expect(text).toMatch(/filed/i)
    expect(text).toMatch(/opt in|choose on purpose/i)
    expect(text).toMatch(/never be this|separate product/i)
  })

  it('says data is not sold', () => {
    expect(all).toMatch(/do not sell it/i)
  })

  it('offers export and deletion, with no reason required', () => {
    expect(all).toMatch(/delete/i)
    expect(all).toMatch(/do not have to give a reason/i)
  })
})

describe('the Data Covenant reads the way the vision says to write', () => {
  it('uses none of the retired vocabulary', () => {
    for (const banned of [/\blifecycle\b/i, /\bplatform\b/i]) {
      expect(all, String(banned)).not.toMatch(banned)
    }
  })

  it('promises no one a longer life', () => {
    for (const re of [/live longer/i, /longer life/i, /extend .{0,12}life/i]) {
      expect(all, String(re)).not.toMatch(re)
    }
  })

  it('is written in plain words, not as a privacy policy', () => {
    // If this reads like a policy nobody will read it, and an unread promise is
    // not a promise.
    for (const legalese of [
      /hereby/i,
      /aforementioned/i,
      /pursuant to/i,
      /we reserve the right/i,
      /may, from time to time/i,
      /third[- ]part(y|ies) partners/i,
    ]) {
      expect(all, String(legalese)).not.toMatch(legalese)
    }
  })

  it('keeps sentences short enough to be read', () => {
    const sentences = all
      .split(/(?<=[.!?])\s+/)
      .map((x) => x.trim())
      .filter((x) => x.split(/\s+/).length > 2)
    const tooLong = sentences.filter((x) => x.split(/\s+/).length > 45)
    expect(tooLong, tooLong.join(' | ')).toEqual([])
  })
})

describe('structure', () => {
  it('every section has a heading and something in it', () => {
    for (const s of COVENANT) {
      expect(s.id, s.heading).toMatch(/^[a-z-]+$/)
      expect(s.heading.length, s.id).toBeGreaterThan(3)
      expect(s.body.length + (s.promises?.length ?? 0), s.id).toBeGreaterThan(0)
      for (const p of [...s.body, ...(s.promises ?? [])]) {
        expect(p.trim().length, s.id).toBeGreaterThan(20)
      }
    }
  })

  it('has unique section ids, so they can be linked to', () => {
    const ids = COVENANT.map((s) => s.id)
    expect(new Set(ids).size).toBe(ids.length)
  })

  it('leads with what the data is never used for', () => {
    // Ordering is the message. A page that opened with "what it does get used
    // for" would be a marketing page.
    expect(COVENANT[1].id).toBe('never')
  })
})
