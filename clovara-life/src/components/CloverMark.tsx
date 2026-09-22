/**
 * The Clovara mark: four rounded lobes with circular holes, arranged in a plus
 * formation, filled with the signature orange-to-green gradient.
 *
 * Drawn as a single evenodd path so the holes are genuinely transparent rather
 * than punched with a matching background colour — it sits correctly on cream,
 * on white and on green.
 */

const circle = (cx: number, cy: number, r: number) =>
  `M${cx - r},${cy}a${r},${r} 0 1,0 ${r * 2},0a${r},${r} 0 1,0 ${-r * 2},0`

const LOBE_R = 8.6
const HOLE_R = 2.5
const OFFSET = 8.4
const C = 24

const lobes = [
  [C, C - OFFSET],
  [C + OFFSET, C],
  [C, C + OFFSET],
  [C - OFFSET, C],
] as const

// Holes sit slightly toward the centre of each lobe's outer half.
const holes = [
  [C, C - OFFSET - 1.6],
  [C + OFFSET + 1.6, C],
  [C, C + OFFSET + 1.6],
  [C - OFFSET - 1.6, C],
] as const

const path = [
  ...lobes.map(([x, y]) => circle(x, y, LOBE_R)),
  ...holes.map(([x, y]) => circle(x, y, HOLE_R)),
].join(' ')

export function CloverMark({ size = 30, id = 'clover' }: { size?: number; id?: string }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 48 48"
      role="img"
      aria-label="Clovara"
      className="shrink-0"
    >
      <defs>
        <linearGradient id={`${id}-grad`} x1="8%" y1="0%" x2="82%" y2="100%">
          <stop offset="0%" stopColor="#D98A26" />
          <stop offset="48%" stopColor="#8FA83E" />
          <stop offset="100%" stopColor="#1E7A46" />
        </linearGradient>
      </defs>
      <path d={path} fill={`url(#${id}-grad)`} fillRule="evenodd" clipRule="evenodd" />
    </svg>
  )
}

export function Wordmark({ size = 30 }: { size?: number }) {
  return (
    <span className="inline-flex items-center gap-2.5">
      <CloverMark size={size} />
      <span className="font-display text-[21px] font-semibold leading-none tracking-[-0.015em] text-ink">
        Clovara <span className="font-medium italic text-forest">Life</span>
      </span>
    </span>
  )
}
