/**
 * Client errors, first-party (BACKLOG UB7).
 *
 * When the first cohort hits something broken, we should know before they
 * tell us — without sending anything to an error service, which the Data
 * Covenant would have to mention. So a crash becomes one more `client_error`
 * event in the same queue as everything else: the message and the component
 * only, scrubbed, never a stack (stacks carry URLs, and URLs carry pet ids).
 *
 * Error messages can still contain what a person typed ("Cannot read 'x' of
 * Bruno's…"), so the message is scrubbed of anything shaped like an email, a
 * link or a long number, and capped. A few per session at most: a render loop
 * must not fill the queue and push out the funnel events.
 */
import type { AnalyticsEvent, EventProps } from './events'

export type ErrorKind = 'render' | 'window' | 'promise'

const MAX_PER_SESSION = 5

/** Pure: a message with the personal-looking parts replaced. */
export function scrubMessage(raw: unknown): string {
  const s = typeof raw === 'string' ? raw : raw instanceof Error ? raw.message : String(raw ?? '')
  return s
    .replace(/[^\s@]+@[^\s@]+\.[^\s@]+/g, '[email]')
    .replace(/\b(?:https?|blob|data|file):\S+/gi, '[url]')
    .replace(/#\/\S*/g, '[route]')
    .replace(/\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/gi, '[id]')
    .replace(/\d{5,}/g, '[number]')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 120)
}

/** Pure: the nearest component's name from a React component stack, or null. */
export function componentOf(componentStack: string | null | undefined): string | null {
  if (!componentStack) return null
  for (const line of componentStack.split('\n')) {
    const m = line.trim().match(/^(?:at|in)\s+([A-Za-z_$][\w$]*)/)
    if (m && /^[A-Z]/.test(m[1]) && m[1].length <= 40) return m[1]
  }
  return null
}

/**
 * Pure: where in the app, without anything that identifies a pet or a card —
 * the first segment of the route, and for a pet its tab. `#/pet/abc/life`
 * → `pet/life`; `#/card/…` → `card`.
 */
export function routeShape(hash: string): string {
  const parts = hash.replace(/^#\/?/, '').split(/[/?]/).filter(Boolean)
  const first = parts[0] && /^[a-z-]{1,20}$/.test(parts[0]) ? parts[0] : ''
  if (!first) return 'home'
  if (first === 'pet' && parts[2] && /^[a-z-]{1,20}$/.test(parts[2])) return `pet/${parts[2]}`
  return first
}

export function errorProps(
  kind: ErrorKind,
  error: unknown,
  opts: { componentStack?: string | null; hash?: string } = {},
): EventProps {
  return {
    kind,
    message: scrubMessage(error) || '(no message)',
    component: componentOf(opts.componentStack),
    route: routeShape(opts.hash ?? ''),
  }
}

/** Per-session gate: at most a few reports, and never the same one twice. */
export function makeReportGate(max = MAX_PER_SESSION) {
  const seen = new Set<string>()
  return (props: EventProps): boolean => {
    const key = `${props.kind}|${props.message}|${props.component}`
    if (seen.has(key) || seen.size >= max) return false
    seen.add(key)
    return true
  }
}

export interface ErrorGroup {
  message: string
  component: string | null
  route: string | null
  count: number
  visitors: number
  lastAt: string
  lastBuild: string
}

/** Pure: `client_error` events grouped by message and component, most recent first. */
export function errorSummary(events: AnalyticsEvent[], limit = 8): ErrorGroup[] {
  const groups = new Map<string, ErrorGroup & { who: Set<string> }>()
  for (const e of events) {
    if (e.name !== 'client_error') continue
    const message = String(e.props.message ?? '(no message)')
    const component = typeof e.props.component === 'string' ? e.props.component : null
    const key = `${message}|${component}`
    const g = groups.get(key) ?? {
      message,
      component,
      route: null,
      count: 0,
      visitors: 0,
      lastAt: '',
      lastBuild: '',
      who: new Set<string>(),
    }
    g.count++
    g.who.add(e.visitorId)
    if (e.at > g.lastAt) {
      g.lastAt = e.at
      g.lastBuild = e.build
      g.route = typeof e.props.route === 'string' ? e.props.route : null
    }
    groups.set(key, g)
  }
  return [...groups.values()]
    .map(({ who, ...g }) => ({ ...g, visitors: who.size }))
    .sort((a, b) => b.lastAt.localeCompare(a.lastAt))
    .slice(0, limit)
}
