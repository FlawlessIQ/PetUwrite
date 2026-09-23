import { useEffect, useState } from 'react'
import { useAuth } from '../auth/AuthProvider'
import { queuedCount } from '../analytics/track'
import type { AnalyticsEvent, EventName } from '../analytics/events'

/**
 * The internal metrics page (SPEC §3: "a tiny internal dashboard page,
 * route-guarded, is enough"). Reached at `#/admin/metrics`.
 *
 * The guard here is UX, not security. The real gate is the Firestore rule —
 * `life_events` is readable only by `isAdmin()`, so a non-admin who guesses the
 * route gets an empty page and a permission error, not data. Hiding the link is
 * convenience; the rule is the control.
 */

interface Totals {
  counts: Partial<Record<EventName, number>>
  uniqueVisitors: Record<string, Set<string>>
  firstSeen: Map<string, number>
  lastSeen: Map<string, number>
  accuracyScores: number[]
  total: number
}

function summarise(events: AnalyticsEvent[]): Totals {
  const counts: Partial<Record<EventName, number>> = {}
  const uniqueVisitors: Record<string, Set<string>> = {}
  const firstSeen = new Map<string, number>()
  const lastSeen = new Map<string, number>()
  const accuracyScores: number[] = []

  for (const e of events) {
    counts[e.name] = (counts[e.name] ?? 0) + 1
    ;(uniqueVisitors[e.name] ??= new Set()).add(e.visitorId)
    const t = new Date(e.at).getTime()
    if (Number.isFinite(t)) {
      const prevFirst = firstSeen.get(e.visitorId)
      if (prevFirst === undefined || t < prevFirst) firstSeen.set(e.visitorId, t)
      const prevLast = lastSeen.get(e.visitorId)
      if (prevLast === undefined || t > prevLast) lastSeen.set(e.visitorId, t)
    }
    if (e.name === 'accuracy_score' && typeof e.props.score === 'number') {
      accuracyScores.push(e.props.score)
    }
  }
  return { counts, uniqueVisitors, firstSeen, lastSeen, accuracyScores, total: events.length }
}

/**
 * Week-4 retention, derived from session timestamps rather than trusting the
 * `week4_active` event. An event that is emitted once and never re-checked is
 * a claim; a date arithmetic over sessions is a measurement.
 */
function weekFourRetention(t: Totals): { eligible: number; retained: number } {
  const DAY = 86_400_000
  let eligible = 0
  let retained = 0
  for (const [visitor, first] of t.firstSeen) {
    const last = t.lastSeen.get(visitor) ?? first
    const age = Date.now() - first
    if (age < 28 * DAY) continue
    eligible++
    if (last - first >= 21 * DAY) retained++
  }
  return { eligible, retained }
}

const FUNNEL: { name: EventName; label: string }[] = [
  { name: 'reveal_viewed', label: 'Saw the Plan reveal' },
  { name: 'signed_up', label: 'Created an account' },
  { name: 'trial_started', label: 'Started the trial' },
  { name: 'attach_offer_viewed', label: 'Saw the Protect offer' },
  { name: 'attach_bound', label: 'Bound a policy' },
]

export function MetricsDashboard({ onClose }: { onClose: () => void }) {
  const { user, status } = useAuth()
  const [events, setEvents] = useState<AnalyticsEvent[] | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    if (!user) return
    ;(async () => {
      try {
        const [{ getApps, getApp, initializeApp }, fs] = await Promise.all([
          import('firebase/app'),
          import('firebase/firestore'),
        ])
        const { getFirestore, collection, getDocs, query, orderBy, limit, connectFirestoreEmulator } = fs
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
        const snap = await getDocs(
          query(collection(db, 'life_events'), orderBy('at', 'desc'), limit(2000)),
        )
        if (!cancelled) setEvents(snap.docs.map((d) => d.data() as AnalyticsEvent))
      } catch (err) {
        if (!cancelled) {
          setError(
            (err as { code?: string })?.code === 'permission-denied'
              ? 'This account is not an admin on this project.'
              : 'Could not load events.',
          )
        }
      }
    })()
    return () => {
      cancelled = true
    }
  }, [user])

  const t = events ? summarise(events) : null
  const retention = t ? weekFourRetention(t) : null
  const top = t ? (t.uniqueVisitors.reveal_viewed?.size ?? 0) : 0

  return (
    <div className="mx-auto w-full max-w-shell px-5 pb-20 pt-8">
      <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="font-display text-[30px] leading-tight text-ink">Internal metrics</h1>
          <p className="mt-1 text-[14px] text-muted">
            Not a customer surface. Read-only, admin-gated in the Firestore rules.
          </p>
        </div>
        <button type="button" onClick={onClose} className="pill-primary">
          Back to the app
        </button>
      </div>

      {status !== 'signedIn' && (
        <p className="card p-5 text-[15px] text-ink">Sign in with an admin account to see this.</p>
      )}

      {error && (
        <p className="card border-accent/30 bg-accent/10 p-5 text-[15px] text-[#8A5510]">{error}</p>
      )}

      {t && (
        <div className="space-y-5">
          <section className="card overflow-hidden">
            <div className="border-b border-line bg-cream/50 px-5 py-4">
              <h2 className="font-display text-[20px] text-ink">The gates</h2>
              <p className="mt-1 text-[13.5px] text-muted">
                Unique visitors reaching each step, and the rate against the step above.
              </p>
            </div>
            <ul className="divide-y divide-line">
              {FUNNEL.map((step, i) => {
                const n = t.uniqueVisitors[step.name]?.size ?? 0
                const prev = i === 0 ? n : (t.uniqueVisitors[FUNNEL[i - 1].name]?.size ?? 0)
                const rate = prev > 0 ? Math.round((n / prev) * 100) : null
                return (
                  <li key={step.name} className="flex items-baseline justify-between gap-4 px-5 py-3">
                    <span className="text-[15px] text-ink">{step.label}</span>
                    <span className="flex items-baseline gap-3">
                      <span className="font-display text-[20px] text-deep">{n}</span>
                      {i > 0 && (
                        <span className="w-[52px] text-right text-[13px] text-muted">
                          {rate === null ? '—' : `${rate}%`}
                        </span>
                      )}
                    </span>
                  </li>
                )
              })}
            </ul>
          </section>

          <section className="card overflow-hidden">
            <div className="border-b border-line bg-cream/50 px-5 py-4">
              <h2 className="font-display text-[20px] text-ink">Retention and sharpness</h2>
            </div>
            <ul className="divide-y divide-line text-[15px]">
              <li className="flex items-baseline justify-between gap-4 px-5 py-3">
                <span className="text-ink">Week-4 retained</span>
                <span className="text-deep">
                  {retention && retention.eligible > 0
                    ? `${retention.retained} of ${retention.eligible}`
                    : 'nobody is 28 days old yet'}
                </span>
              </li>
              <li className="flex items-baseline justify-between gap-4 px-5 py-3">
                <span className="text-ink">Median plan accuracy</span>
                <span className="text-deep">
                  {t.accuracyScores.length
                    ? `${[...t.accuracyScores].sort((a, b) => a - b)[Math.floor(t.accuracyScores.length / 2)]}%`
                    : 'no scores yet'}
                </span>
              </li>
              <li className="flex items-baseline justify-between gap-4 px-5 py-3">
                <span className="text-ink">Events stored</span>
                <span className="text-deep">{t.total}</span>
              </li>
              <li className="flex items-baseline justify-between gap-4 px-5 py-3">
                <span className="text-ink">Unflushed on this device</span>
                <span className="text-deep">{queuedCount()}</span>
              </li>
            </ul>
          </section>

          <p className="card p-5 text-[13.5px] leading-relaxed text-muted">
            <span className="font-medium text-ink">Read this number honestly.</span> Events buffer
            locally and flush when someone signs in, so a visitor who sees the reveal and never
            signs up is never counted — the top of this funnel ({top} visitors) is an undercount,
            and every rate below it is therefore flattering. A public ingest endpoint on the
            functions codebase closes the gap; until it lands, treat the first step as a floor
            rather than a total.
          </p>
        </div>
      )}
    </div>
  )
}
