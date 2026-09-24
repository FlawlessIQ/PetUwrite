/**
 * The lump diary (SPEC-HORIZON §1.1).
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * THE DEFINING ABSENCE: there is no function here that returns a change, a
 * delta, a percentage or a trend. Not because it was forgotten — because two
 * handheld photographs taken a month apart do not support that measurement, and
 * an owner told "no significant change" will wait.
 *
 * The product shows both pictures side by side and lets a person decide. A test
 * asserts no export of this module has "grew", "change", "delta" or "trend" in
 * its name, so the absence survives somebody later thinking it would be helpful.
 *
 * A SIZE REFERENCE IS WHAT MAKES TWO PHOTOS COMPARABLE AT ALL. A coin, a
 * fingertip, anything of known size in frame. Without one, "it looks bigger" is
 * a phone held closer, and the feature manufactures exactly the illusion it
 * exists to prevent. Photos without a reference are kept and shown, and marked
 * as not comparable.
 * ═══════════════════════════════════════════════════════════════════════════
 *
 * Pure; clock injected.
 */

export interface LumpPhoto {
  /** Download URL of the avatar-sized copy, for rendering. */
  url: string
  /** Storage path of the analysable copy. */
  fullPath: string
  takenAt: string
  /**
   * What was in frame for scale, in the owner's words. Null when they took it
   * without one — which is allowed, and which makes it not comparable.
   */
  sizeReference: string | null
}

export interface Lump {
  id: string
  /** Where on the animal, in the owner's words. */
  location: string
  firstSeen: string
  /** What a vet said about it, if anything. Free text, never interpreted. */
  note?: string
  photos: LumpPhoto[]
}

/** References people actually have to hand. */
export const SIZE_REFERENCES = [
  'A coin',
  'My fingertip',
  'A ruler or tape',
  'A pen lid',
]

export const NEW_LUMP_WARNING =
  'A lump you have just found is a reason to see a vet, not a reason to start a diary. This is for keeping track of something a vet has already looked at and asked you to watch.'

export const SIZE_REFERENCE_WHY =
  'Put something of known size next to it — a coin, your fingertip, a ruler. Without one, a photo taken closer looks bigger, and the two pictures cannot be compared at all.'

export const NO_JUDGEMENT =
  'We do not tell you whether it has changed. Two photographs taken by hand a month apart cannot answer that, and a wrong answer here is the kind that makes somebody wait. Look at them side by side, and take both to your vet.'

/** Oldest first, which is how a sequence is read. */
export function inOrder(photos: LumpPhoto[]): LumpPhoto[] {
  return [...photos].sort((a, b) => a.takenAt.localeCompare(b.takenAt))
}

/** Only photos with a size reference can be set against each other. */
export function comparable(photos: LumpPhoto[]): LumpPhoto[] {
  return inOrder(photos).filter((p) => !!p.sizeReference)
}

export interface LumpState {
  /** Whole days since the first photo. */
  daysTracked: number
  photoCount: number
  /** How many can actually be compared. */
  comparableCount: number
  /** The two the comparison view should show: first and latest comparable. */
  pair: [LumpPhoto, LumpPhoto] | null
  /** Days since the most recent photo. */
  daysSinceLast: number | null
  /** Why a comparison is not available, for the surface to say. */
  blocked: 'none-yet' | 'only-one' | 'no-size-reference' | null
}

export function lumpState(lump: Lump, now: Date): LumpState {
  const all = inOrder(lump.photos ?? [])
  const withRef = comparable(all)
  const first = all[0]
  const last = all[all.length - 1]

  const days = (from: string) =>
    Math.max(0, Math.floor((now.getTime() - Date.parse(from)) / 86_400_000))

  let blocked: LumpState['blocked'] = null
  if (all.length === 0) blocked = 'none-yet'
  else if (all.length === 1) blocked = 'only-one'
  else if (withRef.length < 2) blocked = 'no-size-reference'

  return {
    daysTracked: first ? days(first.takenAt) : 0,
    photoCount: all.length,
    comparableCount: withRef.length,
    pair: withRef.length >= 2 ? [withRef[0], withRef[withRef.length - 1]] : null,
    daysSinceLast: last ? days(last.takenAt) : null,
    blocked,
  }
}

/** What to say about where this diary is, never about the lump itself. */
export function lumpBlockedCopy(state: LumpState): string | null {
  switch (state.blocked) {
    case 'none-yet':
      return 'No photographs yet.'
    case 'only-one':
      return 'One photograph so far. There is nothing to set it against until the next one.'
    case 'no-size-reference':
      return 'Only one of these has something in frame for scale, so they cannot be compared. The next photo with a coin or a fingertip beside it will fix that.'
    default:
      return null
  }
}
