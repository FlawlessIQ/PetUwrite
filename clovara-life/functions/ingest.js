/**
 * Anonymous analytics ingest (AO13 / UB5): counts the visitors who never sign
 * up, so the funnel's first steps stop being an undercount.
 *
 * Accepts only what the app's events already carry — the closed list of event
 * names, flat props through the app's own sanitiser, an anonymous per-browser
 * id — and nothing else. No uid, no names, no emails, no free text: the same
 * rules as a signed-in flush, minus the identity. Pure, apart from the clock
 * passed in; index.js does the HTTP and the write.
 */
const { EVENT_NAMES, sanitizeProps } = require('./generated/events')

const NAMES = new Set(EVENT_NAMES)
const ID = /^[A-Za-z0-9-]{8,64}$/
const MAX_EVENTS = 50
const MAX_AGE_MS = 7 * 86_400_000

/** A batch in → the events worth storing, and how many were refused. */
function validateBatch(body, now) {
  const raw = body && Array.isArray(body.events) ? body.events.slice(0, MAX_EVENTS) : []
  const events = []
  let refused = (body && Array.isArray(body.events) ? body.events.length : 0) - raw.length
  for (const e of raw) {
    const at = e && typeof e.at === 'string' ? Date.parse(e.at) : NaN
    const ok =
      e && NAMES.has(e.name) && ID.test(e.visitorId || '') && ID.test(e.sessionId || '') &&
      Number.isFinite(at) && at <= now.getTime() + 60_000 && now.getTime() - at <= MAX_AGE_MS
    if (!ok) {
      refused++
      continue
    }
    events.push({
      name: e.name,
      props: sanitizeProps(e.props && typeof e.props === 'object' && !Array.isArray(e.props) ? e.props : {}),
      at: new Date(at).toISOString(),
      visitorId: e.visitorId,
      sessionId: e.sessionId,
      build: typeof e.build === 'string' ? e.build.slice(0, 40) : 'unknown',
      uid: null,
      anon: true,
    })
  }
  return { events, refused }
}

/**
 * A sliding window per key (visitor id, and the caller's address). Per
 * instance, so it bounds abuse rather than guaranteeing a number — enough for
 * an endpoint whose worst case is junk analytics, which the name list and the
 * sanitiser already limit.
 */
function makeLimiter({ perMinute = 120, now = () => Date.now() } = {}) {
  const hits = new Map()
  return {
    allow(key, count = 1) {
      const t = now()
      const recent = (hits.get(key) || []).filter((x) => t - x < 60_000)
      if (recent.length + count > perMinute) {
        hits.set(key, recent)
        return false
      }
      for (let i = 0; i < count; i++) recent.push(t)
      hits.set(key, recent)
      if (hits.size > 10_000) hits.clear()
      return true
    },
  }
}

module.exports = { validateBatch, makeLimiter, MAX_EVENTS }
