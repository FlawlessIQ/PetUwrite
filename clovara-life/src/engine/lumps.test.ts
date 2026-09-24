import { describe, expect, it } from 'vitest'
import * as lumps from './lumps'
import {
  comparable,
  inOrder,
  lumpBlockedCopy,
  lumpState,
  NEW_LUMP_WARNING,
  NO_JUDGEMENT,
  SIZE_REFERENCE_WHY,
  type Lump,
  type LumpPhoto,
} from './lumps'

const NOW = new Date('2026-09-24T12:00:00Z')
const daysAgo = (n: number) => new Date(NOW.getTime() - n * 86_400_000).toISOString()

const photo = (over: Partial<LumpPhoto> = {}): LumpPhoto => ({
  url: 'https://example/x.jpg',
  fullPath: 'life/households/h/pets/p/x.jpg',
  takenAt: daysAgo(0),
  sizeReference: 'A coin',
  ...over,
})
const lump = (photos: LumpPhoto[]): Lump => ({
  id: 'l1',
  location: 'Left shoulder',
  firstSeen: daysAgo(60),
  photos,
})

describe('the defining absence', () => {
  it('exports NOTHING that computes a change', () => {
    // Not forgotten — refused. Two handheld photographs a month apart cannot
    // answer "has it grown", and an owner told "no significant change" waits.
    // This test is here so the absence survives somebody later thinking a
    // percentage would be helpful.
    for (const name of Object.keys(lumps)) {
      expect(name, `lumps exports "${name}"`).not.toMatch(
        /grew|grow|change|delta|trend|bigger|smaller|increase|decrease|percent|measure|size(?!_REFERENCE)/i,
      )
    }
  })

  it('says out loud that it will not judge', () => {
    expect(NO_JUDGEMENT).toMatch(/do not tell you whether it has changed/i)
    expect(NO_JUDGEMENT).toMatch(/makes somebody wait/i)
  })

  it('tells somebody a new lump is a vet visit, not a diary entry', () => {
    expect(NEW_LUMP_WARNING).toMatch(/reason to see a vet, not a reason to start a diary/i)
    expect(NEW_LUMP_WARNING).toMatch(/already looked at/i)
  })
})

describe('the size reference', () => {
  it('is what makes two photos comparable at all', () => {
    const l = lump([
      photo({ takenAt: daysAgo(30) }),
      photo({ takenAt: daysAgo(0), sizeReference: null }),
    ])
    const s = lumpState(l, NOW)
    expect(s.photoCount).toBe(2)
    expect(s.comparableCount).toBe(1)
    expect(s.pair).toBeNull()
    expect(s.blocked).toBe('no-size-reference')
  })

  it('explains why, rather than just refusing', () => {
    expect(SIZE_REFERENCE_WHY).toMatch(/taken closer looks bigger/i)
    expect(lumpBlockedCopy(lumpState(lump([photo(), photo({ sizeReference: null })]), NOW))).toMatch(
      /cannot be compared/i,
    )
  })

  it('keeps photos without a reference rather than rejecting them', () => {
    // Somebody photographing a lump at the vet's is not going to stop to find a
    // coin. The picture is still worth having; it just cannot be set against
    // another one.
    const s = lumpState(lump([photo({ sizeReference: null })]), NOW)
    expect(s.photoCount).toBe(1)
  })
})

describe('the pair it shows', () => {
  it('is the first and the latest comparable, not the last two', () => {
    // A month-on-month pair understates a slow change; first-to-latest is the
    // comparison somebody actually wants to put in front of a vet.
    const l = lump([
      photo({ takenAt: daysAgo(90), url: 'first' }),
      photo({ takenAt: daysAgo(60), url: 'middle' }),
      photo({ takenAt: daysAgo(2), url: 'latest' }),
    ])
    const s = lumpState(l, NOW)
    expect(s.pair?.[0].url).toBe('first')
    expect(s.pair?.[1].url).toBe('latest')
  })

  it('skips uncomparable photos when choosing the pair', () => {
    const l = lump([
      photo({ takenAt: daysAgo(90), url: 'first' }),
      photo({ takenAt: daysAgo(30), url: 'noref', sizeReference: null }),
      photo({ takenAt: daysAgo(1), url: 'latest' }),
    ])
    expect(lumpState(l, NOW).pair?.map((p) => p.url)).toEqual(['first', 'latest'])
  })

  it('is null with nothing to compare', () => {
    expect(lumpState(lump([]), NOW).pair).toBeNull()
    expect(lumpState(lump([photo()]), NOW).pair).toBeNull()
  })
})

describe('ordering and elapsed time', () => {
  it('reads oldest first', () => {
    const out = inOrder([photo({ takenAt: daysAgo(1), url: 'b' }), photo({ takenAt: daysAgo(9), url: 'a' })])
    expect(out.map((p) => p.url)).toEqual(['a', 'b'])
  })

  it('does not mutate the input', () => {
    const list = [photo({ takenAt: daysAgo(1), url: 'b' }), photo({ takenAt: daysAgo(9), url: 'a' })]
    inOrder(list)
    expect(list.map((p) => p.url)).toEqual(['b', 'a'])
  })

  it('counts days tracked from the first photo, not from first-seen', () => {
    const s = lumpState(lump([photo({ takenAt: daysAgo(40) }), photo({ takenAt: daysAgo(3) })]), NOW)
    expect(s.daysTracked).toBe(40)
    expect(s.daysSinceLast).toBe(3)
  })

  it('never returns a negative day count for a clock that moved', () => {
    const s = lumpState(lump([photo({ takenAt: new Date(NOW.getTime() + 86_400_000).toISOString() })]), NOW)
    expect(s.daysTracked).toBe(0)
    expect(s.daysSinceLast).toBe(0)
  })

  it('handles an empty diary without throwing', () => {
    const s = lumpState(lump([]), NOW)
    expect(s.photoCount).toBe(0)
    expect(s.daysSinceLast).toBeNull()
    expect(lumpBlockedCopy(s)).toMatch(/No photographs yet/i)
  })

  it('comparable() returns only referenced photos, in order', () => {
    const out = comparable([
      photo({ takenAt: daysAgo(2), url: 'b' }),
      photo({ takenAt: daysAgo(5), url: 'a' }),
      photo({ takenAt: daysAgo(1), url: 'x', sizeReference: null }),
    ])
    expect(out.map((p) => p.url)).toEqual(['a', 'b'])
  })
})
