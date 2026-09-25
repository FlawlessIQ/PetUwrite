import { useEffect, useState } from 'react'
import { useAuth } from '../auth/AuthProvider'
import { queuedCount } from '../analytics/track'
import type { AnalyticsEvent, EventName } from '../analytics/events'
import {
  accuracyDistribution,
  recordsByDay30,
  tier1Completion,
  timeToReveal,
} from '../analytics/phaseMetrics'

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
  total: number
}

function summarise(events: AnalyticsEvent[]): Totals {
  const counts: Partial<Record<EventName, number>> = {}
  const uniqueVisitors: Record<string, Set<string>> = {}
  const firstSeen = new Map<string, number>()
  const lastSeen = new Map<string, number>()

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
  }
  return { counts, uniqueVisitors, firstSeen, lastSeen, total: events.length }
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
  const phase = events
    ? {
        reveal: timeToReveal(events),
        tier1: tier1Completion(events),
        accuracy: accuracyDistribution(events),
        records: recordsByDay30(events, new Date()),
      }
    : null
  const top = t ? (t.uniqueVisitors.reveal_viewed?.size ?? 0) : 0

  return (
    <div className="mx-auto w-full max-w-shell px-5 pb-20 pt-8">
      <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="font-display text-display leading-tight text-ink">Internal metrics</h1>
          <p className="mt-1 text-body-lg text-ink-2">
            Not a customer surface. Read-only, admin-gated in the Firestore rules.
          </p>
        </div>
        <button type="button" onClick={onClose} className="pill-primary">
          Back to the app
        </button>
      </div>

      {status !== 'signedIn' && (
        <p className="card p-5 text-lead text-ink">Sign in with an admin account to see this.</p>
      )}

      {error && (
        <p className="card border-accent/30 bg-accent/10 p-5 text-lead text-amber">{error}</p>
      )}

      {t && (
        <div className="space-y-5">
          <section className="card overflow-hidden">
            <div className="border-b border-line bg-cream/50 px-5 py-4">
              <h2 className="font-display text-heading text-ink">The gates</h2>
              <p className="mt-1 text-body text-ink-2">
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
                    <span className="text-lead text-ink">{step.label}</span>
                    <span className="flex items-baseline gap-3">
                      <span className="font-display text-heading text-deep">{n}</span>
                      {i > 0 && (
                        <span className="w-[52px] text-right text-body-sm text-ink-2">
                          {rate === null ? '—' : `${rate}%`}
                        </span>
                      )}
                    </span>
                  </li>
                )
              })}
            </ul>
          </section>

          {phase && (
            <section className="card overflow-hidden">
              <div className="border-b border-line bg-cream/50 px-5 py-4">
                <h2 className="font-display text-heading text-ink">Phase 1 — the four numbers</h2>
                <p className="mt-1 text-body text-ink-2">
                  SPEC §4.3's metrics for onboarding. Demo pets are excluded from all four —
                  Max, Winston and Luna are walked through in front of investors, which is a
                  session that reveals in seconds and sharpens nothing.
                </p>
              </div>
              <ul className="divide-y divide-line text-lead">
                <li className="px-5 py-3">
                  <div className="flex items-baseline justify-between gap-4">
                    <span className="text-ink">Time to the reveal</span>
                    <span className="text-deep">
                      {phase.reveal.medianSeconds === null
                        ? 'nobody has onboarded yet'
                        : `${phase.reveal.medianSeconds.toFixed(0)}s median`}
                    </span>
                  </div>
                  {phase.reveal.samples > 0 && (
                    <p className="mt-1 text-body-sm text-ink-2">
                      {phase.reveal.p90Seconds?.toFixed(0)}s at the 90th ·{' '}
                      {phase.reveal.withinTarget} of {phase.reveal.samples} inside SPEC's
                      sixty-second target
                    </p>
                  )}
                </li>

                <li className="px-5 py-3">
                  <div className="flex items-baseline justify-between gap-4">
                    <span className="text-ink">Tier-1 answered in the first session</span>
                    <span className="text-deep">
                      {phase.tier1.rate === null
                        ? 'no onboardings yet'
                        : `${Math.round(phase.tier1.rate * 100)}%`}
                    </span>
                  </div>
                  {phase.tier1.sessions > 0 && (
                    <p className="mt-1 text-body-sm text-ink-2">
                      {phase.tier1.completedAny} of {phase.tier1.sessions} sessions ·{' '}
                      {phase.tier1.meanFields.toFixed(1)} fields each on average, sessions that
                      answered nothing included
                    </p>
                  )}
                </li>

                <li className="px-5 py-3">
                  <div className="flex items-baseline justify-between gap-4">
                    <span className="text-ink">Plan accuracy</span>
                    <span className="text-deep">
                      {phase.accuracy.medianScore === null
                        ? 'no scores yet'
                        : `${Math.round(phase.accuracy.medianScore)}% median`}
                    </span>
                  </div>
                  {phase.accuracy.visitors > 0 && (
                    <div className="mt-2 space-y-1">
                      {phase.accuracy.bands.map((b) => {
                        const pct = Math.round((b.count / phase.accuracy.visitors) * 100)
                        return (
                          <div key={b.label} className="flex items-center gap-3">
                            <span className="w-[66px] shrink-0 text-body-sm text-ink-2">
                              {b.label}
                            </span>
                            <span className="h-2 flex-1 overflow-hidden rounded-full bg-cream">
                              <span
                                className="block h-full rounded-full bg-forest"
                                style={{ width: `${pct}%` }}
                              />
                            </span>
                            <span className="w-[34px] shrink-0 text-right text-body-sm text-ink-2">
                              {b.count}
                            </span>
                          </div>
                        )
                      })}
                      <p className="pt-1 text-body-sm text-ink-2">
                        One score per visitor — their highest.
                      </p>
                    </div>
                  )}
                </li>

                <li className="px-5 py-3">
                  <div className="flex items-baseline justify-between gap-4">
                    <span className="text-ink">Records connected by day 30</span>
                    <span className="text-deep">
                      {phase.records.eligible === 0
                        ? 'nobody is 30 days old yet'
                        : `${phase.records.connected} of ${phase.records.eligible}`}
                    </span>
                  </div>
                  <p className="mt-1 text-body-sm text-ink-2">
                    Vet-record extraction (P1.7) is blocked on the Firestore security review, so
                    this reads zero because the feature does not exist — not because nobody uses
                    it.
                  </p>
                </li>
              </ul>
            </section>
          )}

          <section className="card overflow-hidden">
            <div className="border-b border-line bg-cream/50 px-5 py-4">
              <h2 className="font-display text-heading text-ink">Retention and volume</h2>
            </div>
            <ul className="divide-y divide-line text-lead">
              <li className="flex items-baseline justify-between gap-4 px-5 py-3">
                <span className="text-ink">Week-4 retained</span>
                <span className="text-deep">
                  {retention && retention.eligible > 0
                    ? `${retention.retained} of ${retention.eligible}`
                    : 'nobody is 28 days old yet'}
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

          <p className="card p-5 text-body leading-relaxed text-ink-2">
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
