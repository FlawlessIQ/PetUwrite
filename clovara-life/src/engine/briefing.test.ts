import { describe, expect, it } from 'vitest'
import {
  BRIEFING_EMAIL_ENABLED,
  buildBriefing,
  HOT_C,
  NULL_ENVIRONMENT,
} from './briefing'
import { project } from './project'
import type { PetProfile } from '../data/types'

const NOW = new Date('2026-09-24T07:00:00Z')
const daysAgo = (n: number) => new Date(NOW.getTime() - n * 86_400_000).toISOString()

const pet = (over: Partial<PetProfile> = {}): PetProfile => ({
  id: 'p',
  name: 'Scout',
  species: 'dog',
  breedId: 'labrador-retriever',
  birthDate: '2019-04-02',
  sex: 'female',
  weightLb: 68,
  conditionIds: [],
  conditionsReviewed: true,
  bodyConditionScore: 3,
  activity: 'moderate',
  dental: 'weekly',
  neutered: true,
  knownSince: daysAgo(200),
  lastReviewedAt: daysAgo(10),
  ...over,
})
const brief = (p: PetProfile, env?: Parameters<typeof buildBriefing>[3]) =>
  buildBriefing(p, project(p, { now: NOW }), NOW, env)

describe('it never invents a reason', () => {
  it('says there is nothing, when there is nothing', () => {
    // A briefing padded to feel valuable trains people to stop reading it, and
    // that is paid for on the day it matters.
    const b = brief(pet())
    expect(b.items).toHaveLength(0)
    expect(b.nothingToSay).toMatch(/Nothing needs doing for Scout today/i)
  })

  it('carries no generic advice anywhere in the file', () => {
    const b = brief(pet())
    const blob = `${b.nothingToSay ?? ''} ${b.items.map((i) => i.text).join(' ')}`
    expect(blob).not.toMatch(
      /\b(remember to|make sure you|did you know|top tip|why not|consider|it is important)\b/i,
    )
  })

  it('adds the stage line only when nothing else is true', () => {
    const quiet = brief(pet())
    expect(quiet.nothingToSay).toMatch(/stage/i)
    const busy = brief(
      pet({
        medications: [
          { id: 'm', name: 'Metacam', amount: 'Half a tablet', frequency: 'twice', startedOn: daysAgo(3), given: [] },
        ],
      }),
    )
    expect(busy.nothingToSay).toBeNull()
    expect(busy.items.every((i) => i.from !== 'stage')).toBe(true)
  })

  it('every item says where it came from', () => {
    const b = brief(
      pet({
        medications: [
          { id: 'm', name: 'Metacam', amount: 'Half a tablet', frequency: 'twice', startedOn: daysAgo(3), quantity: 4, given: [] },
        ],
      }),
    )
    expect(b.items.length).toBeGreaterThan(0)
    for (const i of b.items) {
      expect(['medication', 'vaccination', 'review', 'lump-diary', 'stage', 'environment']).toContain(i.from)
    }
  })
})

describe('what it actually says', () => {
  const withMed = (over = {}) =>
    pet({
      medications: [
        { id: 'm', name: 'Metacam', amount: 'Half a tablet', frequency: 'twice', startedOn: daysAgo(3), given: [], ...over },
      ],
    })

  it('leads with medication, which is the only thing that is genuinely today', () => {
    expect(brief(withMed()).items[0].from).toBe('medication')
    expect(brief(withMed()).items[0].text).toMatch(/Half a tablet, 2 today/)
  })

  it('counts down the remainder once some are logged', () => {
    const b = brief(withMed({ given: [new Date(NOW.getTime() - 3600_000).toISOString()] }))
    expect(b.items[0].text).toMatch(/1 more today/)
  })

  it('says nothing about medication once the day is done', () => {
    const b = brief(
      withMed({
        given: [
          new Date(NOW.getTime() - 3600_000).toISOString(),
          new Date(NOW.getTime() - 1800_000).toISOString(),
        ],
      }),
    )
    expect(b.items.some((i) => i.id === 'med-m')).toBe(false)
  })

  it('warns when a course is running out, attributing the count', () => {
    const b = brief(withMed({ quantity: 4 }))
    expect(b.items.some((i) => /runs out in about 2 days, by your count/.test(i.text))).toBe(true)
  })

  it('mentions a vaccination only while the window is open', () => {
    const puppy = pet({ birthDate: daysAgo(56), knownSince: daysAgo(10), lastReviewedAt: undefined })
    expect(brief(puppy).items.some((i) => i.from === 'vaccination')).toBe(true)
    expect(brief(pet()).items.some((i) => i.from === 'vaccination')).toBe(false)
  })

  it('mentions the annual review when it falls due', () => {
    const due = pet({ knownSince: daysAgo(1000), lastReviewedAt: daysAgo(400) })
    expect(brief(due).items.some((i) => i.from === 'review')).toBe(true)
  })

  it('mentions a lump only when one is already being tracked and is stale', () => {
    const tracked = (days: number) =>
      pet({
        lumps: [
          {
            id: 'l',
            location: 'Left shoulder',
            firstSeen: daysAgo(90),
            photos: [{ url: 'u', fullPath: 'f', takenAt: daysAgo(days), sizeReference: 'A coin' }],
          },
        ],
      })
    expect(brief(tracked(40)).items.some((i) => i.from === 'lump-diary')).toBe(true)
    expect(brief(tracked(3)).items.some((i) => i.from === 'lump-diary')).toBe(false)
    // And never for a lump nobody has photographed — that is not a reminder,
    // it is nagging about something they may have decided not to track.
    expect(
      brief(pet({ lumps: [{ id: 'l', location: 'x', firstSeen: daysAgo(90), photos: [] }] })).items
        .some((i) => i.from === 'lump-diary'),
    ).toBe(false)
  })
})

describe('the environment seam', () => {
  it('has nothing behind it, and that is not an error', () => {
    expect(NULL_ENVIRONMENT.available).toBe(false)
  })

  it('a briefing without weather is a complete briefing', () => {
    const b = brief(pet())
    expect(b.items.some((i) => i.from === 'environment')).toBe(false)
    expect(b.nothingToSay).toBeTruthy()
  })

  it('says something about heat only when a provider actually reported it', () => {
    expect(brief(pet(), { highToday: 28, pollen: null }).items.some((i) => i.id === 'heat')).toBe(true)
    expect(brief(pet(), { highToday: 12, pollen: null }).items.some((i) => i.id === 'heat')).toBe(false)
    expect(brief(pet(), { highToday: null, pollen: null }).items.some((i) => i.id === 'heat')).toBe(false)
  })

  it('gives the pavement check, which is the useful half of a heat warning', () => {
    const b = brief(pet(), { highToday: HOT_C + 4, pollen: null })
    expect(b.items.find((i) => i.id === 'heat')!.text).toMatch(/check the pavement with your hand/i)
  })

  it('does not warn a cat about pavements', () => {
    const cat = pet({ species: 'cat', breedId: 'domestic-shorthair' })
    expect(brief(cat, { highToday: 30, pollen: null }).items.some((i) => i.id === 'heat')).toBe(false)
  })
})

describe('when a pet has died', () => {
  it('there is no briefing at all — not even "nothing to say"', () => {
    const b = brief(pet({ diedOn: daysAgo(10) }))
    expect(b.items).toHaveLength(0)
    expect(b.nothingToSay).toBeNull()
  })

  it('not even with medication still on the record', () => {
    const b = brief(
      pet({
        diedOn: daysAgo(10),
        medications: [
          { id: 'm', name: 'Metacam', amount: 'Half a tablet', frequency: 'twice', startedOn: daysAgo(30), given: [] },
        ],
      }),
    )
    expect(b.items).toHaveLength(0)
  })
})

describe('delivery', () => {
  it('email is off, pending the consent decision', () => {
    // A daily email is a different consent from a monthly one, and it is not an
    // engineering default.
    expect(BRIEFING_EMAIL_ENABLED).toBe(false)
  })
})
