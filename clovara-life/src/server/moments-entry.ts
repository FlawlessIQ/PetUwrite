/**
 * The one thing the Life functions need from the app's engines: what is due
 * for a stored pet today. Bundled by `npm run build:moments` into
 * functions/generated/moments.js, so the email scheduler and the app answer
 * from the same code rather than a copy that drifts. verify-moments-bundle
 * fails if the generated file is stale.
 */
import { profileFromFirestore } from '../data/fromFirestore'
import { momentsDue, type Moment } from '../engine/moments'

export type { Moment }

/** A Firestore pet document (with its id) → what is worth an email today. */
export function momentsForStoredPet(stored: unknown, now: Date): Moment[] {
  const mapped = profileFromFirestore(stored)
  return mapped ? momentsDue(mapped.profile, now) : []
}

/** For the email: the pet's name as the owner gave it, or null. */
export function petNameOfStored(stored: unknown): string | null {
  return profileFromFirestore(stored)?.profile.name ?? null
}
