/**
 * The Clovara mark — and the only place the app renders it.
 *
 * docs/DESIGN.md §1: every rendering of the clover derives from
 * `assets/images/clovara_mark_refined.svg`, and redrawing it is prohibited.
 * This component used to draw its own: four circles and four holes in a plus,
 * which the design system lists as drift. It now imports the canonical file,
 * so Vite fingerprints it into one immutable, cacheable asset and every surface
 * that shows the mark shows the same one.
 *
 * Rendered as an <img>, so it cannot be recoloured, stretched or given effects —
 * which are three of the things §1 forbids. The SVG's own viewBox keeps its
 * aspect ratio inside a square box.
 */
import markUrl from '../../../assets/images/clovara_mark_refined.svg'

/** §1: "minimum render 20px (below that, omit)". */
export const MARK_MIN_PX = 20

export function CloverMark({
  size = 30,
  label = 'Clovara',
  watermark = false,
}: {
  size?: number
  /** Empty string when the mark is decorative next to the word "Clovara". */
  label?: string
  /**
   * §1 watermark exception: forest surfaces only. The caller supplies the 12°
   * rotation and 14% opacity on its wrapper; this brightens the gradient so it
   * reads against forest rather than disappearing into it, as styleguide.html
   * does.
   */
  watermark?: boolean
}) {
  if (size < MARK_MIN_PX) return null
  return (
    <img
      src={markUrl}
      width={size}
      height={size}
      alt={label}
      aria-hidden={label === '' ? true : undefined}
      draggable={false}
      className="shrink-0 select-none"
      style={watermark ? { filter: 'brightness(3)' } : undefined}
    />
  )
}

/**
 * The wordmark: "Clovara" in Playfair Display Bold, ink, −0.02em, with the mark
 * at cap-height × 1.25 and a 10–14px gap (§1).
 *
 * Playfair's cap height is about 0.708em, so the mark is 0.885 × the font size —
 * floored at the 20px minimum, which at the header's size is the binding rule.
 *
 * "Life" is kept, in italic forest: it is the product's sub-brand and is on
 * every surface that says which product you are in. §1 specifies the wordmark as
 * "Clovara" alone; the lockup is flagged for Conor rather than removed.
 */
export function Wordmark({ fontSize = 22 }: { fontSize?: number }) {
  const mark = Math.max(MARK_MIN_PX, Math.round(fontSize * 0.708 * 1.25))
  return (
    <span className="inline-flex items-center gap-3">
      <CloverMark size={mark} label="" />
      <span
        className="font-display font-bold leading-none tracking-[-0.02em] text-ink"
        style={{ fontSize }}
      >
        Clovara <span className="font-medium italic text-forest">Life</span>
      </span>
    </span>
  )
}
