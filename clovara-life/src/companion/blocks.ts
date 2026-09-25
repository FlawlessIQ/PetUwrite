/**
 * The companion's conversation kit — the schema (docs/DESIGN.md §5b).
 *
 * THE COMPANION NEVER RENDERS FREE TEXT. Every reply is a typed array of these
 * blocks, the renderer maps each block to one component, and anything it does
 * not recognise degrades to plain text. That is what makes every reply
 * on-brand by construction — and it is where compliance lives: there is no
 * diagnosis component to render into. Medical content can only reach the
 * screen as `history_ref` (what is already on the record) or `watch_signs`
 * (what to look for, with a route), and `watch_signs` at `now` always brings an
 * `escalate` with it.
 *
 * The scripted engine fills these today; a model fills them later
 * (SPEC-COMPANION C3), through the same schema and the same normaliser.
 */
import { RED_FLAG_HEADLINE } from '../data/redFlags'

export type Urgency = 'monitor' | 'soon' | 'now'

export type CompanionBlock =
  /** Inline bold only: no headings, no lists. */
  | { kind: 'text'; md: string }
  /** "From Max's history" — the memory moment. `date` may be empty; one is never invented. */
  | { kind: 'history_ref'; lead: string; note: string; date: string }
  | { kind: 'watch_signs'; intro: string; signs: string[]; urgency: Urgency }
  /** At most three; at most one primary. */
  | { kind: 'actions'; items: { label: string; style: 'primary' | 'ghost'; action: string }[] }
  | { kind: 'booking_confirm'; vet: string; when: string; prepared: string }
  /** At most one per reply. */
  | { kind: 'product_ref'; productId: string; why: string }
  /** The urgent-vet routing card. Amber, not red; calm copy. */
  | { kind: 'escalate'; reason: string }

export type BlockKind = CompanionBlock['kind']

/**
 * Every kind the renderer knows, and nothing else. A test holds this list to
 * the seven in §5b — adding a kind is a design decision, not a code change.
 */
export const BLOCK_KINDS = [
  'text',
  'history_ref',
  'watch_signs',
  'actions',
  'booking_confirm',
  'product_ref',
  'escalate',
] as const satisfies readonly BlockKind[]

export const MAX_ACTIONS = 3

/** §5b watch_signs: urgency drives the closing line, in a calm voice. */
export const URGENCY_CLOSING: Record<Urgency, string> = {
  // NEW COPY for this kit — not yet through P2's read of judgement copy.
  monitor: 'Worth keeping an eye on — nothing to act on today.',
  // The scripted thread's own words.
  soon: 'Worth a vet’s eyes — not an emergency, but soon.',
  // Deliberately empty: `now` always brings an escalate block, which carries
  // the routing. A second, differently worded urgent line would compete with it.
  now: '',
}

/**
 * Whatever arrives — from the script today, from a model later — is made safe
 * to render here, before any component sees it.
 *
 * - unknown kinds, and known kinds with the wrong shape, become `text`
 * - text loses headings and list markers (inline bold only)
 * - actions are capped at three, with no more than one primary
 * - product_ref is kept once per reply
 * - watch_signs at `now` gets an escalate after it if it does not have one
 */
export function normalise(raw: readonly unknown[]): CompanionBlock[] {
  const out: CompanionBlock[] = []
  let products = 0
  for (const r of raw) {
    const b = coerce(r)
    if (b.kind === 'product_ref') {
      if (products++ > 0) continue
    }
    if (b.kind === 'actions') {
      let primaries = 0
      const items = b.items.slice(0, MAX_ACTIONS).map((it) => {
        if (it.style === 'primary' && primaries++ > 0) return { ...it, style: 'ghost' as const }
        return it
      })
      if (items.length === 0) continue
      out.push({ kind: 'actions', items })
      continue
    }
    out.push(b)
  }
  // `now` never stands alone.
  const nowAt = out.findIndex((b) => b.kind === 'watch_signs' && b.urgency === 'now')
  if (nowAt !== -1 && !out.some((b) => b.kind === 'escalate')) {
    // The existing red-flag headline rather than new urgent copy: the words
    // somebody reads when their animal is in trouble are A1's to review, and a
    // second phrasing written here would not have been.
    out.splice(nowAt + 1, 0, { kind: 'escalate', reason: RED_FLAG_HEADLINE })
  }
  return out
}

const str = (v: unknown): v is string => typeof v === 'string'

/** Anything that is not exactly a known block becomes readable text. */
function coerce(r: unknown): CompanionBlock {
  const o = (r && typeof r === 'object' ? r : {}) as Record<string, unknown>
  switch (o.kind) {
    case 'text':
      if (str(o.md)) return { kind: 'text', md: plainInline(o.md) }
      break
    case 'history_ref':
      if (str(o.lead) && str(o.note)) return { kind: 'history_ref', lead: o.lead, note: o.note, date: str(o.date) ? o.date : '' }
      break
    case 'watch_signs':
      if (str(o.intro) && Array.isArray(o.signs) && (o.urgency === 'monitor' || o.urgency === 'soon' || o.urgency === 'now')) {
        return { kind: 'watch_signs', intro: o.intro, signs: o.signs.filter(str), urgency: o.urgency }
      }
      break
    case 'actions':
      if (Array.isArray(o.items)) {
        const items = o.items
          .map((i) => (i && typeof i === 'object' ? (i as Record<string, unknown>) : {}))
          .filter((i) => str(i.label) && str(i.action))
          .map((i) => ({ label: i.label as string, action: i.action as string, style: i.style === 'primary' ? ('primary' as const) : ('ghost' as const) }))
        return { kind: 'actions', items }
      }
      break
    case 'booking_confirm':
      if (str(o.vet) && str(o.when) && str(o.prepared)) return { kind: 'booking_confirm', vet: o.vet, when: o.when, prepared: o.prepared }
      break
    case 'product_ref':
      if (str(o.productId) && str(o.why)) return { kind: 'product_ref', productId: o.productId, why: o.why }
      break
    case 'escalate':
      if (str(o.reason)) return { kind: 'escalate', reason: o.reason }
      break
  }
  return { kind: 'text', md: plainInline(fallbackText(o)) }
}

/** The most readable thing we can find in a block we do not understand. */
function fallbackText(o: Record<string, unknown>): string {
  for (const k of ['md', 'text', 'note', 'reason', 'intro', 'content', 'message']) {
    if (str(o[k]) && o[k]) return o[k] as string
  }
  return ''
}

/** Headings and list markers stripped: §5b text is inline bold only. */
export function plainInline(md: string): string {
  return md
    .split('\n')
    .map((l) => l.replace(/^\s{0,3}(#{1,6}\s+|[-*+]\s+|\d+[.)]\s+|>\s?)/, ''))
    .join(' ')
    .replace(/\s+/g, ' ')
    .trim()
}

/** `**bold**` → segments. Nothing else is markup. */
export function inlineSegments(md: string): { text: string; bold: boolean }[] {
  const out: { text: string; bold: boolean }[] = []
  const re = /\*\*([^*]+)\*\*/g
  let last = 0
  for (let m = re.exec(md); m; m = re.exec(md)) {
    if (m.index > last) out.push({ text: md.slice(last, m.index), bold: false })
    out.push({ text: m[1], bold: true })
    last = m.index + m[0].length
  }
  if (last < md.length) out.push({ text: md.slice(last), bold: false })
  return out
}
