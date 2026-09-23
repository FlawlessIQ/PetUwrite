import { describe, expect, it } from 'vitest'
import { daysUntilReview, lastBirthday, projectionShift, reviewDue, reviewItems } from './review'
import { fieldsOn, ASK_REGISTRY } from '../data/askRegistry'
import type { PetProfile } from '../data/types'

const NOW = new Date('2026-09-23T12:00:00Z')
const ago = (days: number) => new Date(NOW.getTime() - days * 86_400_000).toISOString()

const pet = (over: Partial<PetProfile> = {}): PetProfile => ({
  id: 'p',
  name: 'Scout',
  species: 'dog',
  breedId: 'labrador-retriever',
  birthDate: '2017-04-02',
  sex: 'female',
  weightLb: 68,
  conditionIds: [],
  ...over,
})

describe('when a review is due', () => {
  // NOW is 2026-09-23. A birthday of 2017-04-02 means the last one was
  // 2026-04-02, about six months ago.
  const BIRTH = '2017-04-02'

  it('is due once a birthday has passed since the last review', () => {
    expect(reviewDue({ knownSince: ago(1000), lastReviewedAt: ago(400), birthDate: BIRTH }, NOW)).toBe(
      true,
    )
    // Reviewed in July, after the April birthday. Not due again until next April.
    expect(reviewDue({ knownSince: ago(1000), lastReviewedAt: ago(70), birthDate: BIRTH }, NOW)).toBe(
      false,
    )
  })

  it('is due for a pet we have known a year and never reviewed', () => {
    expect(reviewDue({ knownSince: ago(400), birthDate: BIRTH }, NOW)).toBe(true)
  })

  it('waits until we have known them a year, whatever their birthday says', () => {
    // The load-bearing case. A nine-year-old rescue adopted six days ago has a
    // birthday behind them and no year for us to ask about. "Anything change
    // this year?" is a strange way to meet someone's dog.
    expect(reviewDue({ knownSince: ago(6), birthDate: BIRTH }, NOW)).toBe(false)
    expect(reviewDue({ knownSince: ago(300), birthDate: BIRTH }, NOW)).toBe(false)
  })

  it('anchors on the birthday, so a late review does not drift the ritual later', () => {
    // Known for years, reviewed 13 months ago — which was before this April's
    // birthday, so one is due. An anniversary-of-last-review rule would agree
    // here, but would then set next year's date 13 months out and keep sliding.
    const pet = { knownSince: ago(2000), lastReviewedAt: ago(395), birthDate: BIRTH }
    expect(reviewDue(pet, NOW)).toBe(true)
    // After reviewing today, the next one is the next birthday — not a year
    // from today.
    const reviewedNow = { ...pet, lastReviewedAt: NOW.toISOString() }
    expect(reviewDue(reviewedNow, NOW)).toBe(false)
    expect(daysUntilReview(reviewedNow, NOW)).toBeLessThan(365)
  })

  it('is not due without knowing when we met them', () => {
    expect(reviewDue({ birthDate: BIRTH }, NOW)).toBe(false)
    expect(reviewDue({ lastReviewedAt: ago(400), birthDate: BIRTH }, NOW)).toBe(false)
  })

  it('is not due on an unparseable date rather than throwing or always firing', () => {
    expect(reviewDue({ knownSince: 'sometime', birthDate: BIRTH }, NOW)).toBe(false)
    expect(reviewDue({ knownSince: ago(400), birthDate: 'not a date' }, NOW)).toBe(false)
  })

  it('finds the last birthday on either side of the turn of the year', () => {
    // A December birthday, asked in September: the last one was last December.
    expect(new Date(lastBirthday('2018-12-20', NOW)!).toISOString().slice(0, 10)).toBe('2025-12-20')
    // A February birthday, asked in September: this February.
    expect(new Date(lastBirthday('2018-02-10', NOW)!).toISOString().slice(0, 10)).toBe('2026-02-10')
  })

  it('counts down, and never below zero', () => {
    expect(daysUntilReview({ knownSince: ago(2000), lastReviewedAt: ago(70), birthDate: BIRTH }, NOW)).toBeGreaterThan(
      150,
    )
    expect(daysUntilReview({ knownSince: ago(2000), birthDate: BIRTH }, NOW)).toBe(0)
    expect(daysUntilReview({ birthDate: BIRTH }, NOW)).toBeNull()
  })

  it('a pet known for a month waits for the year, not just the next birthday', () => {
    const soon = { knownSince: ago(30), birthDate: BIRTH }
    expect(daysUntilReview(soon, NOW)).toBeGreaterThan(300)
  })
})

describe('what the review puts in front of someone', () => {
  it('asks only about things that can change in a year', () => {
    const fields = reviewItems(pet()).map((i) => i.field)
    for (const fixed of ['breedId', 'birthDate', 'sex', 'species', 'neuterAgeBand']) {
      expect(fields, `re-asking ${fixed} makes this a form`).not.toContain(fixed)
    }
  })

  it('never re-asks neutering once the answer is yes', () => {
    expect(reviewItems(pet({ neutered: true })).map((i) => i.field)).not.toContain('neutered')
    expect(reviewItems(pet({ neutered: false })).map((i) => i.field)).toContain('neutered')
    expect(reviewItems(pet()).map((i) => i.field)).toContain('neutered')
  })

  it('asks a cat about going out and never asks a dog', () => {
    const cat = reviewItems(pet({ species: 'cat', breedId: 'domestic-shorthair' })).map((i) => i.field)
    expect(cat).toContain('outdoorAccess')
    expect(reviewItems(pet()).map((i) => i.field)).not.toContain('outdoorAccess')
  })

  it('leads with body condition, which is what actually drifts', () => {
    expect(reviewItems(pet())[0].field).toBe('weightLb')
  })

  it('says what we currently hold, in words, so the answer is a correction', () => {
    const items = reviewItems(pet({ bodyConditionScore: 5, activity: 'low', dental: 'rarely' }))
    const by = (f: string) => items.find((i) => i.field === f)!
    expect(by('weightLb').current).toBe('Scout was heavy')
    expect(by('activity').current).toBe('not very active')
    expect(by('dental').current).toBe('teeth cleaned rarely')
  })

  it('admits when it never asked, rather than showing a default as a fact', () => {
    // Showing "moderately active" for a pet nobody asked would be us inventing
    // an answer and then asking them to confirm our invention.
    const items = reviewItems(pet())
    for (const f of ['activity', 'dental']) {
      expect(items.find((i) => i.field === f)!.current).toBe('we have never asked')
    }
    expect(items.find((i) => i.field === 'conditionIds')!.current).toBe('we have never asked')
    expect(
      reviewItems(pet({ conditionsReviewed: true })).find((i) => i.field === 'conditionIds')!.current,
    ).toBe('nothing diagnosed')
  })

  it('describes a cat in words that fit a cat', () => {
    // "short or irregular walks" is a perfectly good description of a dog and a
    // description of no cat at all. The same strings are read back to both.
    const cat = reviewItems(
      pet({ species: 'cat', breedId: 'domestic-shorthair', activity: 'low' }),
    )
    const blob = cat.map((i) => `${i.current} ${i.prompt} ${i.because}`).join(' ')
    expect(blob).not.toMatch(/walk/i)
  })

  it('gives every item a reason about the animal, never about our records', () => {
    for (const i of reviewItems(pet({ species: 'cat', breedId: 'domestic-shorthair' }))) {
      expect(i.because.length, i.field).toBeGreaterThan(20)
      expect(i.because, i.field).not.toMatch(/up to date|our records|complete your|profile/i)
    }
  })

  it('is not a back door around the ask registry', () => {
    // The registry governs what may be asked at all. The review re-confirms; it
    // must never introduce a field nobody registered, or "just one more field"
    // comes back through the yearly screen instead of the onboarding one.
    const registered = new Set(ASK_REGISTRY.map((a) => a.field))
    for (const i of reviewItems(pet({ species: 'cat', breedId: 'domestic-shorthair' }))) {
      expect(registered.has(i.field), `review asks "${i.field}", which no registry entry places anywhere`).toBe(
        true,
      )
    }
  })

  it('only re-confirms fields the Life surface already collects', () => {
    const onLife = new Set(fieldsOn('life'))
    for (const i of reviewItems(pet())) {
      expect(onLife.has(i.field), i.field).toBe(true)
    }
  })
})

describe('the diff', () => {
  it('reports the change in both ends, to a tenth', () => {
    expect(projectionShift({ low: 10.2, high: 13.1 }, { low: 9.7, high: 12.9 })).toEqual({
      low: -0.5,
      high: -0.2,
      unchanged: false,
    })
  })

  it('knows when nothing moved', () => {
    const s = projectionShift({ low: 10.2, high: 13.1 }, { low: 10.2, high: 13.1 })
    expect(s.unchanged).toBe(true)
    expect(s.low).toBe(0)
  })

  it('does not report a rounding artefact as a change', () => {
    // 0.04 of a year is fifteen days and is not news.
    expect(projectionShift({ low: 10.0, high: 13.0 }, { low: 10.04, high: 13.03 }).unchanged).toBe(true)
  })

  it('reports a rise as readily as a fall — it is arithmetic, not a verdict', () => {
    expect(projectionShift({ low: 9.5, high: 12.0 }, { low: 10.0, high: 12.4 })).toEqual({
      low: 0.5,
      high: 0.4,
      unchanged: false,
    })
  })
})

describe('the backfill for pets that predate the review', () => {
  it('anchors a pet with no anchor to today, not to their birthday', async () => {
    const { withReviewAnchor } = await import('../store/localPets')
    const [out] = withReviewAnchor([pet({ birthDate: '2017-04-02' })], NOW)
    expect(out.knownSince).toBe(NOW.toISOString())
    // Dating it to the birthday would make a review instantly overdue for every
    // pet at once, on a screen nobody asked for.
    expect(reviewDue(out, NOW)).toBe(false)
  })

  it('never touches a pet that already has one', () => {
    // A backfill that overwrites resets everybody's clock on every load, and
    // the review would never once come due.
    const existing = pet({ knownSince: ago(400) })
    const petsIn = [existing]
    return import('../store/localPets').then(({ withReviewAnchor }) => {
      const out = withReviewAnchor(petsIn, NOW)
      expect(out).toBe(petsIn)
      expect(out[0].knownSince).toBe(existing.knownSince)
      expect(reviewDue(out[0], NOW)).toBe(true)
    })
  })

  it('returns the same array when there is nothing to do, so no write happens', async () => {
    const { withReviewAnchor } = await import('../store/localPets')
    const petsIn = [pet({ knownSince: ago(10) }), pet({ id: 'q', knownSince: ago(20) })]
    expect(withReviewAnchor(petsIn, NOW)).toBe(petsIn)
  })
})
