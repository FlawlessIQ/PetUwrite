import { describe, expect, it } from 'vitest'
import {
  AVATAR_SIZE,
  FULL_MAX_EDGE,
  MAX_UPLOAD_BYTES,
  describeRejection,
  fitWithin,
  squareCrop,
} from './imageMath'

describe('fitWithin', () => {
  it('scales a large photo down to the long edge, keeping its shape', () => {
    const r = fitWithin({ width: 4032, height: 3024 }, 2048)
    expect(r).toEqual({ width: 2048, height: 1536 })
    expect(r.width / r.height).toBeCloseTo(4032 / 3024, 3)
  })

  it('handles portrait as well as landscape', () => {
    expect(fitWithin({ width: 3024, height: 4032 }, 2048)).toEqual({ width: 1536, height: 2048 })
  })

  it('never upscales', () => {
    // A real 800px photo beats a fake 2048px one for anything we would later
    // want to measure, and upscaling only adds bytes.
    expect(fitWithin({ width: 800, height: 600 }, 2048)).toEqual({ width: 800, height: 600 })
    expect(fitWithin({ width: 40, height: 40 }, 2048)).toEqual({ width: 40, height: 40 })
  })

  it('leaves an image exactly at the limit alone', () => {
    expect(fitWithin({ width: 2048, height: 1000 }, 2048)).toEqual({ width: 2048, height: 1000 })
  })

  it('never returns a zero dimension for a very wide image', () => {
    const r = fitWithin({ width: 10000, height: 3 }, 512)
    expect(r.height).toBeGreaterThanOrEqual(1)
    expect(r.width).toBe(512)
  })

  it('returns nothing sensible for nonsense, rather than NaN', () => {
    for (const bad of [
      { width: 0, height: 100 },
      { width: 100, height: 0 },
      { width: -5, height: 10 },
    ]) {
      expect(fitWithin(bad, 512), JSON.stringify(bad)).toEqual({ width: 0, height: 0 })
    }
    expect(fitWithin({ width: 100, height: 100 }, 0)).toEqual({ width: 0, height: 0 })
  })
})

describe('squareCrop', () => {
  it('takes the largest square that fits', () => {
    expect(squareCrop({ width: 1600, height: 1200 }).size).toBe(1200)
    expect(squareCrop({ width: 1200, height: 1600 }).size).toBe(1200)
  })

  it('centres horizontally', () => {
    const c = squareCrop({ width: 1600, height: 1200 })
    expect(c.sx).toBe(200)
    expect(c.sy).toBe(0)
  })

  it('biases upward on a portrait photo, where the head usually is', () => {
    // A dead-centre crop of a standing dog is a picture of its chest.
    const c = squareCrop({ width: 1200, height: 1800 })
    const centred = Math.round((1800 - 1200) / 2)
    expect(c.sy).toBeLessThan(centred)
    expect(c.sy).toBe(200)
  })

  it('does nothing to an already-square photo', () => {
    expect(squareCrop({ width: 900, height: 900 })).toEqual({ sx: 0, sy: 0, size: 900 })
  })

  it('never crops outside the image', () => {
    for (const s of [
      { width: 1600, height: 1200 },
      { width: 1200, height: 1800 },
      { width: 999, height: 1000 },
      { width: 3, height: 4000 },
    ]) {
      const c = squareCrop(s)
      expect(c.sx + c.size, JSON.stringify(s)).toBeLessThanOrEqual(s.width)
      expect(c.sy + c.size, JSON.stringify(s)).toBeLessThanOrEqual(s.height)
      expect(c.sx).toBeGreaterThanOrEqual(0)
      expect(c.sy).toBeGreaterThanOrEqual(0)
    }
  })
})

describe('what we accept', () => {
  it('keeps enough resolution to be worth analysing later', () => {
    // SPEC §4.2 wants the image kept "for future body-condition trend", which
    // is what this number is for — an avatar-sized copy would not serve it.
    expect(FULL_MAX_EDGE).toBeGreaterThanOrEqual(1024)
    expect(AVATAR_SIZE).toBeLessThan(FULL_MAX_EDGE)
  })

  it('explains a rejection instead of just refusing', () => {
    const tooBig = describeRejection({ type: 'image/jpeg', size: MAX_UPLOAD_BYTES + 1 })
    expect(tooBig).toMatch(/MB/)
    expect(tooBig).toMatch(/smaller size/i)

    const wrongType = describeRejection({ type: 'application/pdf', size: 1000 })
    expect(wrongType).toMatch(/not a photo/i)
  })

  it('accepts what phones actually produce', () => {
    for (const type of ['image/jpeg', 'image/png', 'image/webp', 'image/heic']) {
      expect(describeRejection({ type, size: 3_000_000 }), type).toBeNull()
    }
  })
})
