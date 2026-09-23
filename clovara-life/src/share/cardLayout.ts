/**
 * Layout arithmetic for the shareable cards (SPEC §6.1 Arrival Certificate,
 * §6.7 Gotcha Day — "same share pipeline").
 *
 * Separated from the drawing for the same reason `imageMath` is: canvas does
 * not exist in node, and the arithmetic is the part that goes wrong. Text
 * measurement is injected rather than imported, so wrapping can be tested
 * against a known-width font without a browser.
 *
 * WHAT IS DELIBERATELY NOT ON THESE CARDS: the healthy-years projection. SPEC
 * §6.1 lists photo, name and "her plan begins today", and that is the whole
 * card. A projected range is a claim about one identifiable animal, and putting
 * it on something built to be posted publicly turns a private planning number
 * into a prediction about someone's dog that strangers will read as a deadline.
 */

/** A square card. 1080 is what every platform downsamples from cleanly. */
export const CARD_SIZE = 1080
export const CARD_PADDING = 84

export interface Measure {
  (text: string, fontPx: number, weight?: number): number
}

/**
 * Breaks text into lines that fit `maxWidth`.
 *
 * A word longer than the line is left on its own line rather than broken
 * mid-word: pet names are the input here, and hyphenating somebody's cat is
 * worse than a line that runs slightly wide.
 */
export function wrapText(
  text: string,
  maxWidth: number,
  fontPx: number,
  measure: Measure,
  weight?: number,
): string[] {
  const words = text.split(/\s+/).filter(Boolean)
  if (words.length === 0) return []
  const lines: string[] = []
  let line = words[0]
  for (const word of words.slice(1)) {
    const candidate = `${line} ${word}`
    if (measure(candidate, fontPx, weight) <= maxWidth) line = candidate
    else {
      lines.push(line)
      line = word
    }
  }
  lines.push(line)
  return lines
}

/**
 * The largest size from `sizes` at which `text` fits on one line.
 *
 * Returns the smallest when nothing fits — a very long name renders small
 * rather than overflowing the card, because the card is the keepsake and a
 * name running off the edge of it is the one thing that cannot be forgiven.
 */
export function fitFontSize(
  text: string,
  maxWidth: number,
  sizes: number[],
  measure: Measure,
  weight?: number,
): number {
  const ordered = [...sizes].sort((a, b) => b - a)
  for (const size of ordered) {
    if (measure(text, size, weight) <= maxWidth) return size
  }
  return ordered[ordered.length - 1]
}

/**
 * A circle inscribed in the card's content width, and where to put it.
 *
 * The photo sits in the upper half: a card is read top-down, and the face is
 * what makes somebody stop scrolling.
 */
export function portraitCircle(size = CARD_SIZE): { cx: number; cy: number; r: number } {
  const r = Math.round(size * 0.185)
  return { cx: Math.round(size / 2), cy: Math.round(size * 0.335), r }
}

/**
 * The initial shown when there is no photo.
 *
 * Never a stock animal silhouette, for the same reason as the in-app avatar: a
 * generic dog standing in for a specific dog is a picture of the wrong animal,
 * and this one is going to be shared.
 */
export function initialFor(name: string): string {
  const first = [...name.trim()].find((ch) => /\p{L}|\p{N}/u.test(ch))
  return (first ?? '·').toUpperCase()
}

/** "2 March 2026" — unambiguous everywhere, unlike 03/02/2026. */
export function longDate(iso: string | Date): string {
  const d = typeof iso === 'string' ? new Date(iso) : iso
  if (Number.isNaN(d.getTime())) return ''
  return new Intl.DateTimeFormat('en-GB', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    timeZone: 'UTC',
  }).format(d)
}

/**
 * A filename somebody can find again in their camera roll.
 *
 * Lowercased, punctuation dropped, spaces to hyphens — an apostrophe or a
 * slash in a pet's name must never reach the filesystem.
 */
export function shareFilename(name: string, kind: string, date: Date): string {
  const slug =
    name
      .normalize('NFD')
      .replace(/[̀-ͯ]/g, '')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, 40) || 'pet'
  const stamp = Number.isNaN(date.getTime()) ? '' : `-${date.toISOString().slice(0, 10)}`
  return `clovara-${slug}-${kind}${stamp}.png`
}
