/**
 * The analytics vocabulary and the sanitiser, for the Life functions'
 * anonymous ingest endpoint (AO13 / UB5) — the same closed list of event names
 * and the same prop rules as the app, so the server accepts exactly what the
 * client is allowed to send. Bundled by `npm run build:moments`.
 */
export { EVENT_NAMES, sanitizeProps } from '../analytics/events'
