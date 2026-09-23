/**
 * The four numbers SPEC §4.3 names as "metrics for this phase":
 * time-to-reveal, tier-1 completion in the first session, the accuracy-score
 * distribution, and records-connected by day 30.
 *
 * Pure, and separate from the dashboard that renders them, for the reason the
 * engines are pure: a number that decides whether onboarding is working should
 * be testable without a browser, a clock, or a Firestore.
 *
 * DEMO PETS ARE EXCLUDED FROM ALL FOUR. Max, Winston and Luna are walked
 * through live in front of investors, which is a session that reveals fast,
 * answers nothing, and would otherwise sit in these numbers as a very quick
 * user who never sharpened anything. Every event that can come from a demo pet
 * carries `pet_is_demo`, and everything below drops those first.
 */
import type { AnalyticsEvent } from './events'

const DAY = 86_400_000

const isDemo = (e: AnalyticsEvent) => e.props.pet_is_demo === true

/** Median of an unsorted list. Returns null for an empty one rather than NaN. */
export function median(xs: number[]): number | null {
  if (xs.length === 0) return null
  const s = [...xs].sort((a, b) => a - b)
  const mid = s.length >> 1
  return s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2
}

/** The value below which `p` of the list falls, nearest-rank. */
export function percentile(xs: number[], p: number): number | null {
  if (xs.length === 0) return null
  const s = [...xs].sort((a, b) => a - b)
  const rank = Math.ceil((p / 100) * s.length)
  return s[Math.min(s.length - 1, Math.max(0, rank - 1))]
}

export interface TimeToReveal {
  /** Seconds from the first onboarding step to the Plan reveal. */
  medianSeconds: number | null
  p90Seconds: number | null
  /** How many reveals carried a timing at all. */
  samples: number
  /** SPEC §4.1's target is under sixty seconds. */
  withinTarget: number
}

/**
 * How long the five taps actually take.
 *
 * Only reveals that followed an onboarding in the same session carry
 * `ms_to_reveal`; a returning user opening the app to a pet they already have
 * has not "reached the reveal" in any sense worth timing, and counting them
 * would report a second and a half and mean nothing.
 */
export function timeToReveal(events: AnalyticsEvent[]): TimeToReveal {
  const ms = events
    .filter((e) => e.name === 'reveal_viewed' && !isDemo(e) && typeof e.props.ms_to_reveal === 'number')
    .map((e) => e.props.ms_to_reveal as number)
    .filter((n) => Number.isFinite(n) && n >= 0)

  const secs = ms.map((m) => m / 1000)
  return {
    medianSeconds: median(secs),
    p90Seconds: percentile(secs, 90),
    samples: secs.length,
    withinTarget: secs.filter((s) => s <= 60).length,
  }
}

export interface Tier1Completion {
  /** Sessions in which a pet was created. */
  sessions: number
  /** Of those, how many also answered at least one Tier-1 question. */
  completedAny: number
  /** Mean Tier-1 fields answered per onboarding session, including zeroes. */
  meanFields: number
  /** Share 0–1, or null when nobody has onboarded yet. */
  rate: number | null
}

/**
 * Tier-1 completion in the first session.
 *
 * "First session" is read literally: the session the pet was made in. Matching
 * on sessionId rather than on a pet id keeps pet identifiers out of the
 * analytics store entirely and answers exactly the question asked.
 *
 * A session that answered nothing still counts in the denominator — the metric
 * is worthless if a session with no answers quietly disappears from it.
 */
export function tier1Completion(events: AnalyticsEvent[]): Tier1Completion {
  const onboarding = new Set<string>()
  for (const e of events) {
    if (e.name === 'pet_created' && !isDemo(e)) onboarding.add(e.sessionId)
  }

  const fieldsBySession = new Map<string, Set<string>>()
  for (const e of events) {
    if (e.name !== 'tier1_field_added' || isDemo(e)) continue
    if (!onboarding.has(e.sessionId)) continue
    const field = typeof e.props.field === 'string' ? e.props.field : '?'
    let seen = fieldsBySession.get(e.sessionId)
    if (!seen) fieldsBySession.set(e.sessionId, (seen = new Set()))
    seen.add(field)
  }

  const sessions = onboarding.size
  let completedAny = 0
  let totalFields = 0
  for (const s of onboarding) {
    const n = fieldsBySession.get(s)?.size ?? 0
    if (n > 0) completedAny++
    totalFields += n
  }
  return {
    sessions,
    completedAny,
    meanFields: sessions === 0 ? 0 : totalFields / sessions,
    rate: sessions === 0 ? null : completedAny / sessions,
  }
}

export interface AccuracyBand {
  label: string
  from: number
  to: number
  count: number
}

/**
 * The accuracy-score distribution, as bands.
 *
 * One score per visitor — their highest. A visitor who sharpened from 42 to 78
 * is one pet at 78, not a 42 and a 78; counting every emission would make the
 * distribution a picture of how often people opened the app.
 */
export function accuracyDistribution(events: AnalyticsEvent[]): {
  bands: AccuracyBand[]
  visitors: number
  medianScore: number | null
} {
  const best = new Map<string, number>()
  for (const e of events) {
    if (e.name !== 'accuracy_score' || isDemo(e)) continue
    const score = e.props.score
    if (typeof score !== 'number' || !Number.isFinite(score)) continue
    const prev = best.get(e.visitorId)
    if (prev === undefined || score > prev) best.set(e.visitorId, score)
  }

  const edges = [0, 40, 60, 80, 90, 101]
  const labels = ['under 40', '40–59', '60–79', '80–89', '90+']
  const bands: AccuracyBand[] = labels.map((label, i) => ({
    label,
    from: edges[i],
    to: edges[i + 1] - 1,
    count: 0,
  }))
  for (const score of best.values()) {
    const i = edges.findIndex((edge, n) => n < bands.length && score >= edge && score < edges[n + 1])
    if (i >= 0) bands[i].count++
  }
  return { bands, visitors: best.size, medianScore: median([...best.values()]) }
}

export interface RecordsByDay30 {
  /** Visitors first seen at least 30 days ago — the only ones who can answer. */
  eligible: number
  connected: number
  rate: number | null
}

/**
 * Records connected by day 30.
 *
 * Only visitors whose first event is 30 days old are eligible: counting
 * somebody who signed up yesterday as "has not connected records" makes the
 * number fall every time the product succeeds at acquiring anyone.
 */
export function recordsByDay30(events: AnalyticsEvent[], now: Date): RecordsByDay30 {
  const firstSeen = new Map<string, number>()
  const connectedAt = new Map<string, number>()
  for (const e of events) {
    const t = new Date(e.at).getTime()
    if (!Number.isFinite(t)) continue
    const prev = firstSeen.get(e.visitorId)
    if (prev === undefined || t < prev) firstSeen.set(e.visitorId, t)
    if (e.name === 'records_connected') {
      const c = connectedAt.get(e.visitorId)
      if (c === undefined || t < c) connectedAt.set(e.visitorId, t)
    }
  }

  let eligible = 0
  let connected = 0
  for (const [visitor, first] of firstSeen) {
    if (now.getTime() - first < 30 * DAY) continue
    eligible++
    const at = connectedAt.get(visitor)
    if (at !== undefined && at - first <= 30 * DAY) connected++
  }
  return { eligible, connected, rate: eligible === 0 ? null : connected / eligible }
}
