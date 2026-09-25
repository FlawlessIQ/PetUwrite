import type { BodyConditionScore, Species } from '../data/types'

/**
 * The five body-condition outlines (SPEC §4.2).
 *
 * Top-down views, because that is the view an owner actually has of their pet
 * standing in front of them — and the one every BCS chart uses for the waist.
 * The only thing that changes across the five is the waist: no other cue is
 * reliable from above, and adding decorative differences would make the choice
 * feel harder than it is.
 *
 * Hand-drawn paths rather than an icon set: the repo has no component or icon
 * libraries by design, and five shapes is not a reason to acquire one.
 */

/** Waist inset by score. 1 is the deepest tuck, 5 has none at all. */
const WAIST: Record<BodyConditionScore, number> = { 1: 13, 2: 9, 3: 6, 4: 2, 5: -2 }

export const BCS_LABELS: Record<BodyConditionScore, { label: string; detail: string }> = {
  // Labels are short because five of them share a 320px row. The full
  // description is the accessible name on the button and the line beneath the
  // picker once one is chosen, so nothing is lost to the brevity.
  1: { label: 'Bony', detail: 'Ribs and hips easy to see' },
  2: { label: 'Thin', detail: 'Ribs easy to feel, clear waist' },
  3: { label: 'Ideal', detail: 'Ribs felt with light pressure, visible waist' },
  4: { label: 'Plump', detail: 'Ribs harder to find, waist fading' },
  5: { label: 'Heavy', detail: 'Ribs hard to feel, no waist' },
}

export function Silhouette({
  score,
  species,
  active,
}: {
  score: BodyConditionScore
  species: Species
  active: boolean
}) {
  const w = WAIST[score]
  // DESIGN.md §5 silhouette picker: the selected glyph is forest, the rest
  // ink-3, both solid — the well around it carries the selected state too.
  const stroke = active ? '#1A5C38' : '#656B65'
  const fill = active ? '#1A5C38' : '#656B65'

  return (
    <svg viewBox="0 0 64 88" width="100%" height="100%" aria-hidden="true" className="block">
      {/* head */}
      <ellipse cx="32" cy="14" rx={species === 'cat' ? 10 : 11} ry="9" fill={fill} stroke={stroke} strokeWidth="2" />
      {/* ears — the only species cue, so the shape reads as the right animal */}
      {species === 'cat' ? (
        <>
          <path d="M23 8 L21 1 L28 5 Z" fill={fill} stroke={stroke} strokeWidth="2" strokeLinejoin="round" />
          <path d="M41 8 L43 1 L36 5 Z" fill={fill} stroke={stroke} strokeWidth="2" strokeLinejoin="round" />
        </>
      ) : (
        <>
          <ellipse cx="21" cy="11" rx="4" ry="6" fill={fill} stroke={stroke} strokeWidth="2" />
          <ellipse cx="43" cy="11" rx="4" ry="6" fill={fill} stroke={stroke} strokeWidth="2" />
        </>
      )}
      {/* body — shoulders fixed, waist is the whole story */}
      <path
        d={`M32 23
            C 46 23, 50 32, 50 40
            C 50 48, ${50 - w} 50, ${50 - w} 56
            C ${50 - w} 66, 46 74, 32 74
            C 18 74, ${14 + w} 66, ${14 + w} 56
            C ${14 + w} 50, 14 48, 14 40
            C 14 32, 18 23, 32 23 Z`}
        fill={fill}
        stroke={stroke}
        strokeWidth="2"
        strokeLinejoin="round"
      />
      {/* tail */}
      <path
        d={species === 'cat' ? 'M32 74 C 40 82, 52 82, 54 72' : 'M32 74 C 36 82, 42 84, 45 80'}
        fill="none"
        stroke={stroke}
        strokeWidth="2"
        strokeLinecap="round"
      />
    </svg>
  )
}
