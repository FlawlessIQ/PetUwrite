/**
 * The tracker: the impure glue around `events.ts` and `queue.ts`.
 *
 * Contract with the demo invariant: calling `track()` while signed out loads
 * NOTHING. It appends to a localStorage queue and returns. Firestore is
 * imported only inside `flush()`, and `flush()` is only ever called with a uid
 * in hand — which means only after someone has signed in and the SDK is already
 * loaded for auth anyway. `verify-demo` check 29 enforces this.
 */
import { makeEvent, type EventName, type EventProps, type AnalyticsEvent } from './events'
import { afterFlush, dedupe, enqueue, parseQueue, prepareFlush } from './queue'

const QUEUE_KEY = 'clovara-life.events.v1'
const VISITOR_KEY = 'clovara-life.visitor.v1'
const BUILD = import.meta.env.VITE_BUILD_ID ?? 'dev'

const randomId = () =>
  // crypto.randomUUID is not available on older Safari over plain http.
  typeof crypto !== 'undefined' && 'randomUUID' in crypto
    ? crypto.randomUUID()
    : `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`

/** One per app load. Never persisted — that is what makes it a session. */
const sessionId = randomId()

function readVisitorId(): string {
  try {
    const existing = localStorage.getItem(VISITOR_KEY)
    if (existing) return existing
    const fresh = randomId()
    localStorage.setItem(VISITOR_KEY, fresh)
    return fresh
  } catch {
    // Private window or blocked storage: a per-session id still lets events
    // within this visit be joined, which is better than dropping them.
    return sessionId
  }
}

function readQueue(): AnalyticsEvent[] {
  try {
    return parseQueue(localStorage.getItem(QUEUE_KEY))
  } catch {
    return []
  }
}

function writeQueue(q: AnalyticsEvent[]): void {
  try {
    localStorage.setItem(QUEUE_KEY, JSON.stringify(q))
  } catch {
    /* Storage full or blocked. Analytics must never be the reason a pet fails
       to save, so this is swallowed — the events are simply lost. */
  }
}

/**
 * Records an event. Safe to call from anywhere, at any time, signed in or not.
 * Never throws, never awaits anything, never loads the SDK.
 */
export function track(name: EventName, props: EventProps = {}): void {
  try {
    const event = makeEvent(name, props, {
      visitorId: readVisitorId(),
      sessionId,
      build: BUILD,
      now: new Date(),
    })
    writeQueue(enqueue(readQueue(), event).queue)
  } catch {
    /* Instrumentation must never break the thing it instruments. */
  }
}

let flushing: Promise<number> | null = null

/**
 * Writes everything queued under the given uid and clears what landed.
 *
 * Returns the number written. Concurrency-safe: overlapping calls share one
 * flight, so a sign-in that triggers two flushes does not double-write.
 */
export function flush(uid: string): Promise<number> {
  if (flushing) return flushing
  flushing = (async () => {
    const pending = dedupe(readQueue())
    if (!pending.length) return 0
    const batch = prepareFlush(pending, uid)
    try {
      const [{ getApps, getApp, initializeApp }, fs] = await Promise.all([
        import('firebase/app'),
        import('firebase/firestore'),
      ])
      const { getFirestore, collection, doc, writeBatch, connectFirestoreEmulator } = fs
      const { FIREBASE_CONFIG } = await import('../auth/config')
      const app = getApps().length ? getApp() : initializeApp(FIREBASE_CONFIG)
      const db = getFirestore(app)
      if (import.meta.env.VITE_USE_EMULATORS === '1') {
        try {
          connectFirestoreEmulator(db, '127.0.0.1', 8080)
        } catch {
          /* already connected */
        }
      }

      // Firestore caps a batch at 500 writes, which is also MAX_QUEUED — but
      // chunking keeps that coupling from becoming a silent failure if either
      // number moves.
      const CHUNK = 400
      let written = 0
      for (let i = 0; i < batch.length; i += CHUNK) {
        const slice = batch.slice(i, i + CHUNK)
        const wb = writeBatch(db)
        for (const e of slice) wb.set(doc(collection(db, 'life_events')), e)
        await wb.commit()
        written += slice.length
        writeQueue(afterFlush(readQueue(), slice))
      }
      return written
    } catch {
      // Offline, denied, or the SDK failed to load. The queue is left intact
      // and the next flush retries it — losing analytics is acceptable, losing
      // it silently and permanently on one bad network is not.
      return 0
    }
  })()
  const inFlight = flushing
  inFlight.finally(() => {
    // Only clear if nobody replaced it in the meantime.
    if (flushing === inFlight) flushing = null
  })
  return inFlight
}

/** Exposed for the dashboard's "unflushed on this device" line. */
export function queuedCount(): number {
  return readQueue().length
}

export function visitorId(): string {
  return readVisitorId()
}
