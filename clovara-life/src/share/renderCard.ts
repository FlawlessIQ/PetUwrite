import {
  CARD_PADDING,
  CARD_SIZE,
  fitFontSize,
  initialFor,
  longDate,
  portraitCircle,
  wrapText,
  type Measure,
} from './cardLayout'
import markUrl from '../../../assets/images/clovara_mark_refined.svg'

/**
 * Draws a shareable card (SPEC §6.1, §6.7) and hands back a PNG.
 *
 * The impure half — everything measurable lives in `cardLayout`.
 *
 * THE PHOTO IS OPTIONAL AT EVERY LEVEL. It may be absent, it may fail to load,
 * and it may load from a cross-origin URL that taints the canvas so `toBlob`
 * throws. All three fall back to the pet's initial rather than failing: a card
 * without the photograph is still a keepsake, and an error where the keepsake
 * should be is not.
 */

// Canvas cannot read Tailwind classes, so these mirror the tokens in
// tailwind.config.js by value. docs/DESIGN.md §2 is the source for both.
const CREAM = '#F6F3EB'
const INK = '#1B1E1B'
const FOREST = '#1A5C38'
const DEEP = '#0F3D26'
const INK_2 = '#5C635C'
const LINE = '#E5E1D5'

const DISPLAY = '"Playfair Display", Georgia, serif'
const SANS = 'Poppins, system-ui, -apple-system, sans-serif'

export interface CardContent {
  name: string
  /** "Beagle · 3 years old" — the quiet line under the name. */
  subtitle: string
  /** The line that carries the moment. */
  headline: string
  /** Small, at the foot. */
  footnote: string
  photoUrl?: string
}

/**
 * Loads an image for canvas, or resolves null.
 *
 * `crossOrigin = 'anonymous'` is set BEFORE `src`, which is the only order
 * that works: set afterwards it is ignored and the canvas is tainted, which
 * does not fail here but throws later at `toBlob` — a mile from the cause.
 */
function loadImage(url: string): Promise<HTMLImageElement | null> {
  return new Promise((resolve) => {
    const img = new Image()
    img.crossOrigin = 'anonymous'
    const done = (v: HTMLImageElement | null) => resolve(v)
    img.onload = () => done(img)
    img.onerror = () => done(null)
    // A photo that never loads must not hang the share button forever.
    setTimeout(() => done(null), 8000)
    img.src = url
  })
}

function roundRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
  ctx.beginPath()
  ctx.moveTo(x + r, y)
  ctx.arcTo(x + w, y, x + w, y + h, r)
  ctx.arcTo(x + w, y + h, x, y + h, r)
  ctx.arcTo(x, y + h, x, y, r)
  ctx.arcTo(x, y, x + w, y, r)
  ctx.closePath()
}

/**
 * The canonical mark (DESIGN.md §1), loaded rather than drawn. This used to paint
 * four circles "so there was no asset to fetch" — a third redrawn clover. The
 * file is fingerprinted and almost always already cached from the header, and a
 * card whose mark fails to load is drawn without one rather than with a guess.
 */
function drawMark(ctx: CanvasRenderingContext2D, mark: HTMLImageElement | null, x: number, y: number, size: number) {
  if (!mark) return
  ctx.drawImage(mark, x, y, size, size)
}

/**
 * Renders the card. Returns a PNG blob, or null if the browser cannot.
 *
 * Waits for `document.fonts.ready`: the brand faces are bundled and load
 * asynchronously, and drawing before they arrive silently produces a card in
 * Georgia and system-ui — which looks fine enough that nobody notices it is
 * wrong until it is on somebody's timeline.
 */
async function drawCard(content: CardContent): Promise<Blob | null> {
  const canvas = document.createElement('canvas')
  canvas.width = CARD_SIZE
  canvas.height = CARD_SIZE
  const ctx = canvas.getContext('2d')
  if (!ctx) return null

  try {
    await document.fonts?.ready
  } catch {
    /* no font loading API — system fallbacks are fine */
  }

  const measure: Measure = (text, fontPx, weight = 400) => {
    ctx.font = `${weight} ${fontPx}px ${DISPLAY}`
    return ctx.measureText(text).width
  }

  // ── Ground ───────────────────────────────────────────────────────────────
  ctx.fillStyle = CREAM
  ctx.fillRect(0, 0, CARD_SIZE, CARD_SIZE)
  ctx.strokeStyle = LINE
  ctx.lineWidth = 3
  roundRect(ctx, 28, 28, CARD_SIZE - 56, CARD_SIZE - 56, 40)
  ctx.stroke()

  // ── Wordmark ─────────────────────────────────────────────────────────────
  // §1: Playfair Bold, −0.02em, mark at cap-height × 1.25 (34px → 30px), gap 12.
  const mark = await loadImage(markUrl)
  drawMark(ctx, mark, CARD_PADDING, CARD_PADDING - 1, 30)
  ctx.textAlign = 'left'
  ctx.textBaseline = 'middle'
  ctx.fillStyle = INK
  ctx.font = `700 34px ${DISPLAY}`
  if ('letterSpacing' in ctx) (ctx as CanvasRenderingContext2D & { letterSpacing: string }).letterSpacing = '-0.68px'
  const WORD_X = CARD_PADDING + 42
  ctx.fillText('Clovara', WORD_X, CARD_PADDING + 14)
  // Measured with the tracking still applied, so "Life" sits where the word ends.
  const clovaraWidth = ctx.measureText('Clovara').width
  if ('letterSpacing' in ctx) (ctx as CanvasRenderingContext2D & { letterSpacing: string }).letterSpacing = '0px'
  ctx.fillStyle = FOREST
  ctx.font = `italic 500 34px ${DISPLAY}`
  ctx.fillText('Life', WORD_X + clovaraWidth + 9, CARD_PADDING + 14)

  // ── Portrait ─────────────────────────────────────────────────────────────
  const { cx, cy, r } = portraitCircle()
  const photo = content.photoUrl ? await loadImage(content.photoUrl) : null

  ctx.save()
  ctx.beginPath()
  ctx.arc(cx, cy, r, 0, Math.PI * 2)
  ctx.closePath()
  ctx.clip()
  if (photo) {
    // Cover, not stretch — an animal squashed to a circle is worse than a crop.
    const scale = Math.max((r * 2) / photo.width, (r * 2) / photo.height)
    const w = photo.width * scale
    const h = photo.height * scale
    ctx.drawImage(photo, cx - w / 2, cy - h / 2, w, h)
  } else {
    ctx.fillStyle = '#E4EAE0'
    ctx.fillRect(cx - r, cy - r, r * 2, r * 2)
    ctx.fillStyle = DEEP
    ctx.font = `500 ${Math.round(r * 1.05)}px ${DISPLAY}`
    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'
    ctx.fillText(initialFor(content.name), cx, cy + r * 0.04)
  }
  ctx.restore()

  ctx.strokeStyle = LINE
  ctx.lineWidth = 6
  ctx.beginPath()
  ctx.arc(cx, cy, r + 3, 0, Math.PI * 2)
  ctx.stroke()

  // ── Name ─────────────────────────────────────────────────────────────────
  const contentWidth = CARD_SIZE - CARD_PADDING * 2
  ctx.textAlign = 'center'
  ctx.textBaseline = 'alphabetic'
  const nameSize = fitFontSize(content.name, contentWidth, [72, 88, 104, 118], measure, 500)
  ctx.fillStyle = INK
  ctx.font = `500 ${nameSize}px ${DISPLAY}`
  ctx.fillText(content.name, cx, CARD_SIZE * 0.605)

  // ── Subtitle ─────────────────────────────────────────────────────────────
  ctx.fillStyle = INK_2
  ctx.font = `400 30px ${SANS}`
  ctx.fillText(content.subtitle, cx, CARD_SIZE * 0.605 + 54)

  // ── Headline ─────────────────────────────────────────────────────────────
  ctx.fillStyle = FOREST
  const headlineSize = 44
  ctx.font = `500 ${headlineSize}px ${DISPLAY}`
  const headMeasure: Measure = (t, px, w = 400) => {
    ctx.font = `${w} ${px}px ${DISPLAY}`
    return ctx.measureText(t).width
  }
  const lines = wrapText(content.headline, contentWidth, headlineSize, headMeasure, 500)
  ctx.font = `500 ${headlineSize}px ${DISPLAY}`
  let y = CARD_SIZE * 0.775
  for (const line of lines.slice(0, 2)) {
    ctx.fillText(line, cx, y)
    y += headlineSize * 1.3
  }

  // ── Footnote ─────────────────────────────────────────────────────────────
  ctx.fillStyle = INK_2
  ctx.font = `400 25px ${SANS}`
  ctx.fillText(content.footnote, cx, CARD_SIZE - CARD_PADDING - 6)

  return new Promise((resolve, reject) => {
    try {
      canvas.toBlob((blob) => resolve(blob), 'image/png')
    } catch (err) {
      // Tainted canvas: a cross-origin photo the bucket would not serve with
      // CORS headers. Thrown here rather than at draw time, a mile from the
      // cause, which is why the retry lives one level up.
      reject(err)
    }
  })
}

/**
 * Renders the card, retrying without the photograph if the photo tainted the
 * canvas.
 *
 * A card without the photograph is still a keepsake. An error where the
 * keepsake should be is not, and CORS on a storage bucket is not something to
 * make somebody's shareable card depend on.
 */
export async function renderShareCard(content: CardContent): Promise<Blob | null> {
  try {
    return await drawCard(content)
  } catch {
    if (!content.photoUrl) return null
    try {
      return await drawCard({ ...content, photoUrl: undefined })
    } catch {
      return null
    }
  }
}

/** Convenience for the two cards we ship. */
export function arrivalCard(pet: {
  name: string
  breedName: string
  ageLabel: string
  photoUrl?: string
}, now: Date): CardContent {
  return {
    name: pet.name,
    subtitle: `${pet.breedName} · ${pet.ageLabel}`,
    // A typographic apostrophe, not a typewriter one. This is a keepsake
    // somebody may print, and ' is the detail that makes it look generated.
    headline: `${pet.name}\u2019s plan begins today.`,
    footnote: longDate(now),
    photoUrl: pet.photoUrl,
  }
}

export function gotchaCard(pet: {
  name: string
  breedName: string
  ageLabel: string
  photoUrl?: string
}, years: number, now: Date): CardContent {
  return {
    name: pet.name,
    subtitle: `${pet.breedName} · ${pet.ageLabel}`,
    headline: years === 1 ? `One year home.` : `${years} years home.`,
    footnote: longDate(now),
    photoUrl: pet.photoUrl,
  }
}
