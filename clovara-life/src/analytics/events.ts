/**
 * The event vocabulary. Pure — no IO, no clock unless injected.
 *
 * SPEC §3 names the gates this product is measured on. They are a closed union
 * rather than free strings so a typo is a compile error instead of a silent
 * hole in the funnel six weeks before anyone looks at the number.
 */

export const EVENT_NAMES = [
  // ── The funnel SPEC §3 names ────────────────────────────────────────────
  /** The Plan reveal was seen. Fires pre-account — this is the top of the funnel. */
  'reveal_viewed',
  'trial_started',
  'tier1_field_added',
  'accuracy_score',
  'records_connected',
  /** A confirm-chip was kept or discarded (invariant 8). */
  'extraction_chip',
  'attach_offer_viewed',
  /** The screen of truth was reached (SPEC §5). */
  'attach_truth_viewed',
  'attach_bound',
  'week4_active',
  // ── Churn ───────────────────────────────────────────────────────────────
  'trial_cancelled',
  'subscription_cancelled',
  'payment_failed',
  // ── Supporting, so the gates above can be derived rather than trusted ───
  /** Every app open. week4_active is computed from these, not just asserted. */
  'session_start',
  'signed_up',
  'signed_in',
  'pet_created',
  'pets_imported',
  /** An Arrival or Gotcha Day card was offered and acted on (SPEC §6.1, §6.7). */
  'share_card',
  /** A Socialization Passport stamp was added or removed (SPEC §6.3). */
  'passport_stamp',
  /** An owner recorded a vaccination date (SPEC §6.4). */
  'vaccine_recorded',
  /** The vet-visit summary was copied (SPEC-COMPANION C0). */
  'visit_summary_copied',
  /** Somebody looked up something their pet ate (SPEC §6.5). */
  'safety_check',
  'companion_asked',
  'second_opinion',
  'med_added',
  'med_dose_logged',
  'pet_remembered',
  'lump_started',
  'lump_photo_added',
  'toxin_lookup',
  'poison_line_tapped',
  'emergency_vets_found',
  'emergency_vet_called',
  /** Sitter Mode (SPEC §6.6). */
  'sitter_link_created',
  'sitter_link_revoked',
] as const

export type EventName = (typeof EVENT_NAMES)[number]

/** Values simple enough to query and to reason about a year from now. */
export type EventProps = Record<string, string | number | boolean | null>

export interface AnalyticsEvent {
  name: EventName
  props: EventProps
  /** ISO 8601, set at enqueue time — not at flush time, which may be much later. */
  at: string
  /**
   * Stable per browser, generated locally. Lets a pre-account event be joined
   * to the account it eventually becomes, which is the only way `reveal_viewed`
   * → `trial_started` is a measurable conversion rather than two unrelated
   * numbers.
   */
  visitorId: string
  /** Set on flush, once we know who this was. Null for events never flushed. */
  uid: string | null
  /** One per app load, so sessions can be counted without a server. */
  sessionId: string
  /** Which build produced it. Cheap now, invaluable when a number moves. */
  build: string
}

/** Pure builder. The clock and the ids are injected so this is testable. */
export function makeEvent(
  name: EventName,
  props: EventProps,
  ctx: { visitorId: string; sessionId: string; build: string; now: Date },
): AnalyticsEvent {
  return {
    name,
    props: sanitizeProps(props),
    at: ctx.now.toISOString(),
    visitorId: ctx.visitorId,
    uid: null,
    sessionId: ctx.sessionId,
    build: ctx.build,
  }
}

/**
 * Strips anything that should never reach the events collection.
 *
 * Analytics is the easiest place in a product to accidentally start storing
 * personal data — a pet name here, an email there, and the events collection
 * quietly becomes a second copy of the user database under weaker rules. So
 * values are coerced to the four simple types, deep objects are refused, and
 * long strings are truncated rather than stored whole.
 */
export function sanitizeProps(props: EventProps): EventProps {
  const out: EventProps = {}
  for (const [k, v] of Object.entries(props ?? {})) {
    if (!/^[a-z][a-z0-9_]{0,39}$/.test(k)) continue
    if (v === null || typeof v === 'boolean') {
      out[k] = v
    } else if (typeof v === 'number') {
      out[k] = Number.isFinite(v) ? v : null
    } else if (typeof v === 'string') {
      out[k] = v.slice(0, 120)
    }
    // Anything else — objects, arrays, functions, undefined — is dropped.
  }
  return out
}
