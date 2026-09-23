/**
 * One stopwatch: onboarding start → Plan reveal.
 *
 * SPEC §4.1 sets a target of under sixty seconds for the five taps, which is
 * only a target if somebody measures it. The mark is deliberately narrow —
 * started when the first onboarding step appears, read exactly once when the
 * reveal it produced is shown.
 *
 * READ ONCE, ON PURPOSE. A returning user opening the app to a pet they made
 * last week reaches the reveal in about a second, and a stopwatch that kept
 * answering would report that as a wonderful time-to-reveal. After the mark is
 * taken there is no timing, and `timeToReveal` drops reveals without one.
 */

let startedAt: number | null = null

/** The first onboarding step is on screen. Idempotent within one run. */
export function markOnboardingStart(now: number = Date.now()): void {
  if (startedAt === null) startedAt = now
}

/**
 * Milliseconds since the mark, consuming it. Null when there was no onboarding
 * — which is the common case and must not be reported as zero.
 */
export function takeTimeToReveal(now: number = Date.now()): number | null {
  if (startedAt === null) return null
  const ms = now - startedAt
  startedAt = null
  return ms >= 0 ? ms : null
}

/** Test seam. Nothing in the app calls this. */
export function resetTiming(): void {
  startedAt = null
}
