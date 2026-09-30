/**
 * Where a visitor first came from, and when they come back (ACQUISITION-
 * ONBOARDING-PLAN, AO4).
 *
 * FIRST-PARTY ONLY. The Data Covenant rules out ad pixels on pages about an
 * animal's health, so attribution is what the browser already tells us: the
 * referring site's HOST (never its path, which can carry a search or a name)
 * and any `utm_*` tags on the landing URL. Stored on this device alongside the
 * visitor id and attached to `first_visit` and `signed_up`, so it reaches the
 * events collection only when somebody signs in — the same as every event.
 */
import type { EventProps } from './events'

const FIRST_TOUCH_KEY = 'clovara-life.first-touch.v1'
const LAST_DAY_KEY = 'clovara-life.last-visit-day.v1'

export interface FirstTouch {
  at: string
  referrer_host: string | null
  utm_source: string | null
  utm_medium: string | null
  utm_campaign: string | null
}

/** Pure: what a landing tells us. Our own host as referrer is not a source. */
export function parseSource(href: string, referrer: string, now: Date): FirstTouch {
  let params: URLSearchParams
  let ownHost = ''
  try {
    const u = new URL(href)
    params = u.searchParams
    ownHost = u.host
  } catch {
    params = new URLSearchParams()
  }
  let referrer_host: string | null = null
  try {
    const r = referrer ? new URL(referrer).host : ''
    referrer_host = r && r !== ownHost ? r : null
  } catch {
    referrer_host = null
  }
  const tag = (k: string) => {
    const v = params.get(k)?.trim()
    return v ? v.slice(0, 60) : null
  }
  return {
    at: now.toISOString(),
    referrer_host,
    utm_source: tag('utm_source'),
    utm_medium: tag('utm_medium'),
    utm_campaign: tag('utm_campaign'),
  }
}

/** Pure: days between two instants, whole days, never negative. */
export function daysBetween(from: string, to: Date): number {
  const ms = to.getTime() - Date.parse(from)
  return Number.isFinite(ms) ? Math.max(0, Math.floor(ms / 86_400_000)) : 0
}

/** The event props for a first touch — the shape `first_visit` and `signed_up` carry. */
export function sourceProps(t: FirstTouch | null): EventProps {
  if (!t) return {}
  return {
    referrer_host: t.referrer_host,
    utm_source: t.utm_source,
    utm_medium: t.utm_medium,
    utm_campaign: t.utm_campaign,
  }
}

export function readFirstTouch(): FirstTouch | null {
  try {
    const raw = localStorage.getItem(FIRST_TOUCH_KEY)
    return raw ? (JSON.parse(raw) as FirstTouch) : null
  } catch {
    return null
  }
}

/**
 * Called once per app load. Returns what happened so the caller tracks it:
 * a first visit (with its source), a return on a new day (with days since the
 * first), or nothing (a second load the same day).
 */
export function recordVisit(now: Date = new Date()):
  | { kind: 'first'; touch: FirstTouch }
  | { kind: 'return'; daysSinceFirst: number }
  | { kind: 'same-day' } {
  const today = now.toISOString().slice(0, 10)
  try {
    const existing = readFirstTouch()
    const lastDay = localStorage.getItem(LAST_DAY_KEY)
    localStorage.setItem(LAST_DAY_KEY, today)
    if (!existing) {
      const touch = parseSource(window.location.href, document.referrer, now)
      localStorage.setItem(FIRST_TOUCH_KEY, JSON.stringify(touch))
      return { kind: 'first', touch }
    }
    if (lastDay === today) return { kind: 'same-day' }
    return { kind: 'return', daysSinceFirst: daysBetween(existing.at, now) }
  } catch {
    // Blocked storage: we cannot tell a first visit from a return, so say nothing.
    return { kind: 'same-day' }
  }
}
