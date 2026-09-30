/**
 * The link that travels with a shared card (ACQUISITION-ONBOARDING-PLAN, AO9).
 *
 * A shared Arrival or Gotcha Day card used to be an image and nothing else — a
 * friend who saw it had no way to find Clovara. Now the share carries a link to
 * a page that shows that card and offers "make one for your dog".
 *
 * NOTHING IS UPLOADED, still. The card is drawn on the device (shareImage.ts),
 * so the link carries only the card's own words — the name, the breed, the age,
 * the date, which card — and the page redraws it. No photograph (that stays on
 * the sharer's phone), no pet id, no household, nothing from the record that
 * is not already printed on the image they chose to send. Pure.
 */
import { arrivalCard, gotchaCard, type CardContent } from './renderCard'

export type CardKind = 'arrival' | 'gotcha'

export interface CardLinkFields {
  kind: CardKind
  name: string
  breedName: string
  ageLabel: string
  /** YYYY-MM-DD — the card's own date. */
  date: string
  /** Years home, Gotcha Day only. */
  years?: number
}

const LIMITS = { name: 40, breedName: 60, ageLabel: 30 }
const clean = (s: string, max: number) => s.replace(/[\u0000-\u001f\u007f]/g, '').trim().slice(0, max)

export function cardLink(origin: string, f: CardLinkFields): string {
  const p = new URLSearchParams({
    k: f.kind,
    n: clean(f.name, LIMITS.name),
    b: clean(f.breedName, LIMITS.breedName),
    a: clean(f.ageLabel, LIMITS.ageLabel),
    d: f.date,
  })
  if (f.kind === 'gotcha' && f.years) p.set('y', String(f.years))
  return `${origin}/#/card?${p.toString()}`
}

/**
 * Reads a `#/card?…` hash back. Strict: anything missing, malformed or out of
 * range is null, and the page says the link is incomplete rather than drawing
 * a card with holes in it.
 */
export function parseCardLink(hash: string): CardLinkFields | null {
  const m = /^#\/card\?(.*)$/.exec(hash)
  if (!m) return null
  const p = new URLSearchParams(m[1])
  const kind = p.get('k')
  const name = clean(p.get('n') ?? '', LIMITS.name)
  const breedName = clean(p.get('b') ?? '', LIMITS.breedName)
  const ageLabel = clean(p.get('a') ?? '', LIMITS.ageLabel)
  const date = p.get('d') ?? ''
  if (kind !== 'arrival' && kind !== 'gotcha') return null
  if (!name || !breedName || !ageLabel) return null
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !Number.isFinite(Date.parse(`${date}T12:00:00Z`))) return null
  if (kind === 'gotcha') {
    const years = Number(p.get('y'))
    if (!Number.isInteger(years) || years < 1 || years > 40) return null
    return { kind, name, breedName, ageLabel, date, years }
  }
  return { kind, name, breedName, ageLabel, date }
}

/** The card itself, redrawn from the link — never with a photograph. */
export function cardContentFromLink(f: CardLinkFields): CardContent {
  const when = new Date(`${f.date}T12:00:00Z`)
  const base = { name: f.name, breedName: f.breedName, ageLabel: f.ageLabel }
  return f.kind === 'gotcha' ? gotchaCard(base, f.years ?? 1, when) : arrivalCard(base, when)
}
