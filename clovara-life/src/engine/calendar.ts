/**
 * A pet's dates, for the owner's own calendar (ACQUISITION-ONBOARDING-PLAN,
 * Phase B — the return channel that needs no domain).
 *
 * Every habit in the product works only if somebody opens the app on the right
 * day. Until email can be sent, the owner's own calendar can do the reminding:
 * this lists what is coming up and writes it as a standard .ics file, made on
 * the device and sent nowhere. Pure — the clock is injected.
 *
 * What goes in is only what other engines already know and say in the app:
 * vaccination windows, the socialisation window closing, the yearly check,
 * Gotcha Day. No diagnosis, no product, nothing a pet who has died should get.
 */
import type { PetProfile } from '../data/types'
import { WINDOW_WEEKS } from '../data/socialization'
import { isRemembered } from './remember'
import { vaccineState } from './vaccines'
import { daysUntilReview } from './review'

export interface CalendarEvent {
  /** Stable, so re-adding the file updates rather than duplicates. */
  uid: string
  /** YYYY-MM-DD — all-day events. */
  date: string
  title: string
  description: string
  /** Gotcha Day comes round every year. */
  yearly?: boolean
}

const DAY = 86_400_000
const WEEK = 7 * DAY
const ymd = (d: Date) => d.toISOString().slice(0, 10)
const startOfDay = (d: Date) => new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()))

export function calendarEvents(pet: PetProfile, now: Date): CalendarEvent[] {
  if (isRemembered(pet)) return []
  const today = startOfDay(now)
  const future = (d: Date) => d.getTime() > today.getTime()
  const born = new Date(pet.birthDate)
  const events: CalendarEvent[] = []

  // ── Vaccination windows still ahead ──────────────────────────────────────
  const vacc = vaccineState(pet, now)
  if (vacc.visible) {
    for (const d of vacc.doses) {
      if (d.status === 'recorded' || !future(d.windowOpens)) continue
      events.push({
        uid: `vaccine-${d.dose.id}`,
        date: ymd(d.windowOpens),
        title: `${pet.name}: ${d.vaccine.label}, ${d.dose.label.toLowerCase()}`,
        description: `Around now is when this dose is usually given. Your vet sets the schedule, not us — this is a reminder to check with them and book.`,
      })
    }
  }

  // ── The socialisation window ─────────────────────────────────────────────
  if (Number.isFinite(born.getTime())) {
    const closes = new Date(born.getTime() + WINDOW_WEEKS[pet.species].closes * WEEK)
    const twoWeeksOut = new Date(closes.getTime() - 2 * WEEK)
    const young = pet.species === 'dog' ? 'puppy' : 'kitten'
    if (future(twoWeeksOut)) {
      events.push({
        uid: 'passport-two-weeks',
        date: ymd(twoWeeksOut),
        title: `${pet.name}: two weeks of the easy part left`,
        description: `Until about ${WINDOW_WEEKS[pet.species].closes} weeks old, a ${young} accepts new things far more readily than they ever will again. The passport in ${pet.name}'s health file has ideas. A frightened ${young} has not been socialised — go slowly.`,
      })
    }
    if (future(closes)) {
      events.push({
        uid: 'passport-closes',
        date: ymd(closes),
        title: `${pet.name}: the easy part of socialising ends around now`,
        description: `New things still help after this — they just take more patience. Nothing here is required.`,
      })
    }
  }

  // ── The yearly check ─────────────────────────────────────────────────────
  const days = daysUntilReview(pet, now)
  if (days !== null && days > 0) {
    events.push({
      uid: 'annual-review',
      date: ymd(new Date(today.getTime() + days * DAY)),
      title: `A year with ${pet.name}`,
      description: `Time for the once-a-year check in Clovara: the handful of things that actually change. "Still true" is the most common answer.`,
    })
  }

  // ── Gotcha Day, every year from the first ────────────────────────────────
  if (pet.knownSince && Number.isFinite(Date.parse(pet.knownSince))) {
    const home = new Date(pet.knownSince)
    const first = new Date(Date.UTC(home.getUTCFullYear() + 1, home.getUTCMonth(), home.getUTCDate()))
    let next = first
    while (!future(next)) next = new Date(Date.UTC(next.getUTCFullYear() + 1, next.getUTCMonth(), next.getUTCDate()))
    events.push({
      uid: 'gotcha-day',
      date: ymd(next),
      title: `${pet.name}'s Gotcha Day`,
      description: `Another year since ${pet.name} came home.`,
      yearly: true,
    })
  }

  return events.sort((a, b) => a.date.localeCompare(b.date))
}

// ── .ics (RFC 5545) ─────────────────────────────────────────────────────────

/** Text values escape backslash, semicolon, comma and newlines (§3.3.11). */
function esc(s: string): string {
  return s.replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,').replace(/\r?\n/g, '\\n')
}

/** Lines longer than 75 octets fold with CRLF + space (§3.1), counted in UTF-8. */
function fold(line: string): string {
  const bytes = (s: string) => new TextEncoder().encode(s).length
  if (bytes(line) <= 75) return line
  const out: string[] = []
  let cur = ''
  for (const ch of line) {
    const limit = out.length === 0 ? 75 : 74
    if (bytes(cur + ch) > limit) {
      out.push(cur)
      cur = ch
    } else cur += ch
  }
  out.push(cur)
  return out.join('\r\n ')
}

export function toIcs(pet: PetProfile, events: CalendarEvent[], now: Date): string {
  const stamp = now.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '')
  const compact = (d: string) => d.replace(/-/g, '')
  const nextDay = (d: string) => compact(ymd(new Date(Date.parse(d) + DAY)))
  const lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Clovara//Clovara Life//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    `X-WR-CALNAME:${esc(`${pet.name} — Clovara`)}`,
  ]
  for (const e of events) {
    lines.push(
      'BEGIN:VEVENT',
      // Stable per pet and per kind of date, so adding the file again after a
      // vaccination is recorded updates the calendar instead of doubling it.
      `UID:${esc(`${pet.id}-${e.uid}@clovara-life`)}`,
      `DTSTAMP:${stamp}`,
      `DTSTART;VALUE=DATE:${compact(e.date)}`,
      `DTEND;VALUE=DATE:${nextDay(e.date)}`,
      ...(e.yearly ? ['RRULE:FREQ=YEARLY'] : []),
      `SUMMARY:${esc(e.title)}`,
      `DESCRIPTION:${esc(e.description)}`,
      'TRANSP:TRANSPARENT',
      'BEGIN:VALARM',
      'ACTION:DISPLAY',
      `DESCRIPTION:${esc(e.title)}`,
      // 9am on the day, rather than midnight.
      'TRIGGER;RELATED=START:PT9H',
      'END:VALARM',
      'END:VEVENT',
    )
  }
  lines.push('END:VCALENDAR')
  return lines.map(fold).join('\r\n') + '\r\n'
}
