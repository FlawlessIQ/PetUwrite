/**
 * UI glyphs as outline icons (docs/DESIGN.md §5): 1.7px stroke, round caps and
 * joins, drawn on a 24px grid.
 *
 * These replace typographic characters — ✓ → ▾ ⓘ — that neither Poppins nor
 * Playfair Display contains. Each one fell through to whatever system font had
 * the glyph, which is §3's "system-font fallthrough" in miniature: a different
 * weight, a different shape, and a different one on every platform.
 *
 * Decorative by default. Where the glyph was the only carrier of meaning, the
 * caller keeps a word next to it — status is never colour or icon alone (§5).
 */
const PATHS = {
  check: 'M5 12.5l4.5 4.5L19 7.5',
  'arrow-right': 'M5 12h14M13 6l6 6-6 6',
  'chevron-down': 'M6.5 9.5L12 15l5.5-5.5',
  info: 'M12 11v5.5M12 7.75v.01',
} as const

export type IconName = keyof typeof PATHS

export function Icon({
  name,
  size = 16,
  className = '',
  label,
  active = false,
}: {
  name: IconName
  size?: number
  className?: string
  /** Only when the icon is the sole carrier of meaning. */
  label?: string
  /** §5: 2.1px stroke for the active state. */
  active?: boolean
}) {
  return (
    <svg
      viewBox="0 0 24 24"
      width={size}
      height={size}
      fill="none"
      stroke="currentColor"
      strokeWidth={active ? 2.1 : 1.7}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={`inline-block shrink-0 ${className}`}
      role={label ? 'img' : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
    >
      {name === 'info' && <circle cx="12" cy="12" r="9" />}
      <path d={PATHS[name]} />
    </svg>
  )
}
