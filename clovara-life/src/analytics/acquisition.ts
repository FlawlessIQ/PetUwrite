/**
 * Where the cohort came from, and whether they came back (BACKLOG UB6).
 *
 * Pure — the clock is injected. Reads only what `first_visit` and
 * `return_visit` already carry (ACQUISITION-ONBOARDING-PLAN, AO4): the
 * referring host, the `utm_*` tags and days since the first visit.
 */
import type { AnalyticsEvent, EventName } from './events'

const DAY = 86_400_000

/** The name a visitor's first visit is filed under: the tag, else the site, else direct. */
export function sourceOf(e: AnalyticsEvent): string {
  const tag = e.props.utm_source
  if (typeof tag === 'string' && tag.trim()) return tag.trim().toLowerCase()
  const host = e.props.referrer_host
  if (typeof host === 'string' && host.trim()) return host.trim().toLowerCase().replace(/^www\./, '')
  return 'direct'
}

export interface SourceRow {
  source: string
  /** Unique visitors reaching each step, in the order the steps were given. */
  counts: number[]
}

/**
 * Each step of the funnel, per source. A visitor belongs to the source of
 * their earliest `first_visit`; visitors with none (before AO4 shipped, or
 * storage blocked) are left out rather than guessed. The biggest `limit - 1`
 * sources are shown and the rest summed into "everything else".
 */
export function funnelBySource(
  events: AnalyticsEvent[],
  steps: EventName[],
  limit = 6,
): SourceRow[] {
  const firstAt = new Map<string, { at: number; source: string }>()
  for (const e of events) {
    if (e.name !== 'first_visit') continue
    const at = Date.parse(e.at)
    const prev = firstAt.get(e.visitorId)
    if (!prev || at < prev.at) firstAt.set(e.visitorId, { at, source: sourceOf(e) })
  }

  const reached = new Map<string, Set<string>[]>()
  for (const { source } of firstAt.values()) {
    if (!reached.has(source)) reached.set(source, steps.map(() => new Set()))
  }
  for (const e of events) {
    const who = firstAt.get(e.visitorId)
    const i = steps.indexOf(e.name)
    if (!who || i < 0) continue
    reached.get(who.source)![i].add(e.visitorId)
  }

  const rows = [...reached.entries()]
    .map(([source, sets]) => ({ source, counts: sets.map((s) => s.size) }))
    .sort((a, b) => b.counts[0] - a.counts[0] || a.source.localeCompare(b.source))
  if (rows.length <= limit) return rows
  const kept = rows.slice(0, limit - 1)
  const rest = rows.slice(limit - 1)
  return [
    ...kept,
    {
      source: `everything else (${rest.length})`,
      counts: steps.map((_, i) => rest.reduce((n, r) => n + r.counts[i], 0)),
    },
  ]
}

export interface ReturnRate {
  day: number
  /** First visits at least `day` days ago — the only ones who could have come back by then. */
  eligible: number
  /** Of those, how many came back on day `day` or later. */
  returned: number
}

/**
 * Day-1, day-7 and day-28 returns: of the visitors whose first visit is old
 * enough, how many have a `return_visit` at least that many days after it.
 */
export function returnRates(events: AnalyticsEvent[], now: Date, days = [1, 7, 28]): ReturnRate[] {
  const first = new Map<string, number>()
  const furthest = new Map<string, number>()
  for (const e of events) {
    if (e.name === 'first_visit') {
      const at = Date.parse(e.at)
      const prev = first.get(e.visitorId)
      if (Number.isFinite(at) && (prev === undefined || at < prev)) first.set(e.visitorId, at)
    } else if (e.name === 'return_visit') {
      const d = Number(e.props.days_since_first)
      if (Number.isFinite(d)) furthest.set(e.visitorId, Math.max(furthest.get(e.visitorId) ?? 0, d))
    }
  }
  return days.map((day) => {
    let eligible = 0
    let returned = 0
    for (const [visitor, at] of first) {
      if (now.getTime() - at < day * DAY) continue
      eligible++
      if ((furthest.get(visitor) ?? -1) >= day) returned++
    }
    return { day, eligible, returned }
  })
}

// ── Campaign links ─────────────────────────────────────────────────────────

export const CAMPAIGN_MEDIUMS = ['partner', 'social', 'email', 'print', 'referral'] as const

/** Lower case, hyphens for spaces, nothing a reader would have to decode. */
export function tagValue(s: string): string {
  return s
    .trim()
    .toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/[^a-z0-9_-]/g, '')
    .replace(/-{2,}/g, '-')
    .slice(0, 60)
}

/**
 * A link to the front door carrying `utm_*` tags. Returns null without a
 * source — an untagged link is just the site, and would be filed as direct.
 */
export function campaignLink(
  origin: string,
  tags: { source: string; medium: string; campaign: string },
): string | null {
  const source = tagValue(tags.source)
  if (!source) return null
  const params = new URLSearchParams({ utm_source: source })
  const medium = tagValue(tags.medium)
  const campaign = tagValue(tags.campaign)
  if (medium) params.set('utm_medium', medium)
  if (campaign) params.set('utm_campaign', campaign)
  return `${origin.replace(/\/+$/, '')}/?${params.toString()}`
}
