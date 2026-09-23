import { describe, expect, it } from 'vitest'
import {
  CARD_SIZE,
  fitFontSize,
  initialFor,
  longDate,
  portraitCircle,
  shareFilename,
  wrapText,
} from './cardLayout'

/** A fake font where every character is exactly 0.5em wide. */
const measure = (text: string, fontPx: number) => text.length * fontPx * 0.5

describe('wrapText', () => {
  it('breaks at the last word that fits', () => {
    // 20 chars at 10px = 100px wide lines.
    expect(wrapText('the quick brown fox jumps', 100, 10, measure)).toEqual([
      'the quick brown fox',
      'jumps',
    ])
  })

  it('returns one line when it already fits', () => {
    expect(wrapText('short', 1000, 10, measure)).toEqual(['short'])
  })

  it('never breaks a word in half, even one too long for the line', () => {
    // Pet names are the input. Hyphenating somebody's cat is worse than a wide
    // line, and worse than the alternative people actually notice.
    expect(wrapText('Bartholomew', 20, 10, measure)).toEqual(['Bartholomew'])
  })

  it('handles empty and whitespace input without producing a blank line', () => {
    expect(wrapText('', 100, 10, measure)).toEqual([])
    expect(wrapText('   ', 100, 10, measure)).toEqual([])
  })

  it('collapses runs of whitespace rather than preserving them', () => {
    expect(wrapText('a    b', 1000, 10, measure)).toEqual(['a b'])
  })
})

describe('fitFontSize', () => {
  it('picks the largest size that fits on one line', () => {
    // "Max" is 3 chars; at 100px that is 150px, at 60px it is 90px.
    expect(fitFontSize('Max', 100, [60, 80, 100], measure)).toBe(60)
    expect(fitFontSize('Max', 200, [60, 80, 100], measure)).toBe(100)
  })

  it('does not depend on the order the sizes are given in', () => {
    expect(fitFontSize('Max', 100, [100, 60, 80], measure)).toBe(60)
  })

  it('falls back to the smallest rather than overflowing the card', () => {
    // A name nothing fits. Rendering it small is recoverable; running off the
    // edge of the keepsake is not.
    expect(fitFontSize('Bartholomew Wigglesworth III', 40, [60, 80, 100], measure)).toBe(60)
  })
})

describe('the portrait circle', () => {
  it('sits in the upper half, where a face stops a scroll', () => {
    const c = portraitCircle()
    expect(c.cy).toBeLessThan(CARD_SIZE / 2)
  })

  it('stays inside the card on every edge', () => {
    for (const size of [1080, 640, 2000]) {
      const c = portraitCircle(size)
      expect(c.cx - c.r).toBeGreaterThan(0)
      expect(c.cx + c.r).toBeLessThan(size)
      expect(c.cy - c.r).toBeGreaterThan(0)
      expect(c.cy + c.r).toBeLessThan(size)
    }
  })
})

describe('the fallback initial', () => {
  it('takes the first letter, uppercased', () => {
    expect(initialFor('max')).toBe('M')
    expect(initialFor('  luna ')).toBe('L')
  })

  it('handles accents and non-Latin names', () => {
    expect(initialFor('Élodie')).toBe('É')
    expect(initialFor('小白')).toBe('小')
  })

  it('skips leading punctuation and emoji rather than rendering them', () => {
    expect(initialFor('"Winston"')).toBe('W')
    expect(initialFor('🐕 Rex')).toBe('R')
  })

  it('never returns an empty string', () => {
    expect(initialFor('')).toBe('·')
    expect(initialFor('!!!')).toBe('·')
  })
})

describe('longDate', () => {
  it('is unambiguous, unlike 03/02/2026', () => {
    expect(longDate('2026-03-02')).toBe('2 March 2026')
  })

  it('returns empty for nonsense rather than "Invalid Date"', () => {
    expect(longDate('not a date')).toBe('')
  })
})

describe('shareFilename', () => {
  it('is something findable in a camera roll', () => {
    expect(shareFilename('Max', 'arrival', new Date('2026-09-23'))).toBe(
      'clovara-max-arrival-2026-09-23.png',
    )
  })

  it('never lets punctuation from a pet name reach the filesystem', () => {
    // An apostrophe, a slash and a space are all ordinary in a pet's name and
    // none of them belong in a filename.
    expect(shareFilename("O'Malley / Jr", 'arrival', new Date('2026-09-23'))).toBe(
      'clovara-o-malley-jr-arrival-2026-09-23.png',
    )
  })

  it('strips accents rather than emitting them raw', () => {
    expect(shareFilename('Élodie', 'gotcha', new Date('2026-09-23'))).toBe(
      'clovara-elodie-gotcha-2026-09-23.png',
    )
  })

  it('falls back to a name when nothing survives slugging', () => {
    expect(shareFilename('🐕', 'arrival', new Date('2026-09-23'))).toBe(
      'clovara-pet-arrival-2026-09-23.png',
    )
  })

  it('does not run on forever for a very long name', () => {
    const f = shareFilename('a'.repeat(200), 'arrival', new Date('2026-09-23'))
    expect(f.length).toBeLessThan(80)
  })
})
