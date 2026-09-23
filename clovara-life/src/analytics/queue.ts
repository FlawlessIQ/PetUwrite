/**
 * The event queue. Pure functions over arrays — storage and network live in
 * `track.ts`.
 *
 * Why a queue at all: the most valuable event in the funnel (`reveal_viewed`)
 * fires before there is an account, and writing it needs Firestore, and loading
 * Firestore on the signed-out path would break the demo invariant that
 * `verify-demo` check 29 enforces. So events buffer locally against a
 * `visitorId` and flush the moment there is a session to attribute them to.
 *
 * The honest limitation, stated rather than hidden: a visitor who never signs
 * in never flushes, so their events are never counted. That undercounts the top
 * of the funnel. The fix is a public ingest endpoint on the functions codebase
 * (no SDK, just a fetch), which lands with P0.5 — until then the dashboard says
 * so on the page rather than quietly reporting a conversion rate that is wrong
 * in a flattering direction.
 */
import type { AnalyticsEvent } from './events'

/**
 * Hard cap. A browser left open for weeks on a flaky connection must not grow
 * an unbounded localStorage entry and start throwing QuotaExceededError on
 * every write — which would take out pet saving too, since they share storage.
 */
export const MAX_QUEUED = 500

export interface EnqueueResult {
  queue: AnalyticsEvent[]
  /** How many were discarded to stay under the cap. */
  dropped: number
}

/**
 * Appends, trimming the OLDEST first when over the cap.
 *
 * Oldest-first is deliberate: if we have to lose events, the recent ones
 * describe what the user is doing now and are likelier to reach a flush. The
 * count of what was dropped is kept so the dashboard can show a gap rather
 * than pretend completeness.
 */
export function enqueue(
  queue: AnalyticsEvent[],
  event: AnalyticsEvent,
  max = MAX_QUEUED,
): EnqueueResult {
  const next = [...queue, event]
  if (next.length <= max) return { queue: next, dropped: 0 }
  const dropped = next.length - max
  return { queue: next.slice(dropped), dropped }
}

/**
 * Stamps the queue with the uid it is about to be written under and returns
 * what to send. The rules require `uid == request.auth.uid` on every event, so
 * an event flushed under the wrong identity is rejected — which is why this is
 * done at flush time and not at enqueue time.
 */
export function prepareFlush(queue: AnalyticsEvent[], uid: string): AnalyticsEvent[] {
  return queue.map((e) => ({ ...e, uid }))
}

/**
 * Removes what was successfully written, keeping anything that arrived during
 * the flight. A flush that takes two seconds must not silently discard the
 * events logged in those two seconds.
 */
export function afterFlush(
  current: AnalyticsEvent[],
  flushed: AnalyticsEvent[],
): AnalyticsEvent[] {
  if (!flushed.length) return current
  const sent = new Set(flushed.map(identity))
  return current.filter((e) => !sent.has(identity(e)))
}

/**
 * Identity of an event for de-duplication. Two events with the same name at the
 * same instant in the same session are the same event; a timestamp alone is not
 * enough because two different events can share a millisecond.
 */
function identity(e: AnalyticsEvent): string {
  return `${e.sessionId}|${e.at}|${e.name}`
}

/** Drops exact duplicates, which a retried flush can otherwise create. */
export function dedupe(queue: AnalyticsEvent[]): AnalyticsEvent[] {
  const seen = new Set<string>()
  return queue.filter((e) => {
    const k = identity(e)
    if (seen.has(k)) return false
    seen.add(k)
    return true
  })
}

/** Parses a persisted queue, discarding anything that is not a usable event. */
export function parseQueue(raw: unknown): AnalyticsEvent[] {
  if (typeof raw !== 'string') return []
  let parsed: unknown
  try {
    parsed = JSON.parse(raw)
  } catch {
    return []
  }
  if (!Array.isArray(parsed)) return []
  return parsed.filter(isEvent).slice(-MAX_QUEUED)
}

function isEvent(v: unknown): v is AnalyticsEvent {
  if (!v || typeof v !== 'object') return false
  const e = v as Record<string, unknown>
  return (
    typeof e.name === 'string' &&
    typeof e.at === 'string' &&
    typeof e.visitorId === 'string' &&
    typeof e.sessionId === 'string' &&
    !!e.props &&
    typeof e.props === 'object'
  )
}
