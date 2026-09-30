/**
 * What is worth an email today, for one pet (ACQUISITION-ONBOARDING-PLAN, AO6).
 *
 * Moments, not a newsletter: each is something another engine already knows is
 * due, said in words the app already uses, and each has a stable `key` so the
 * sender can make sure it goes once. A daily scheduler calls this; whether
 * anything is sent depends on the owner having opted in (off by default — a
 * regular email is a different consent from signing up, DECISIONS X4).
 *
 * Pure: the clock is injected. Silent for a demo pet and for a pet who has
 * died (MUST_GO_QUIET 'email').
 */
import type { PetProfile } from '../data/types'
import { FIRST_NIGHT_ESCALATION } from '../data/firstNight'
import { WINDOW_WEEKS } from '../data/socialization'
import { isRemembered } from './remember'
import { firstNightState } from './firstNight'
import { vaccineState } from './vaccines'
import { passportState } from './passport'
import { reviewDue } from './review'
import { gotchaState } from './gotchaDay'

export type MomentKind = 'first-nights' | 'vaccine' | 'passport' | 'review' | 'gotcha'

export interface Moment {
  /** Unique per pet and occasion — the sender records it and never repeats it. */
  key: string
  kind: MomentKind
  subject: string
  /** Paragraphs, plain text. The template adds the greeting and the footer. */
  lines: string[]
}

const DAY = 86_400_000

export function momentsDue(pet: PetProfile, now: Date): Moment[] {
  if (pet.demo || isRemembered(pet)) return []
  const out: Moment[] = []
  const young = pet.species === 'dog' ? 'puppy' : 'kitten'

  // ── The first night: once, the morning after they come home ──────────────
  const fn = firstNightState(pet, now)
  if (fn.active && fn.hoursHome >= 12 && fn.hoursHome < 36) {
    out.push({
      key: 'first-nights',
      kind: 'first-nights',
      subject: `${pet.name}'s first night, and what is normal`,
      lines: [
        `Hiding, shaking, refusing food, or sleeping for hours are all normal in the first days. Keep the world small — one room, few people — and let ${pet.name} come to you.`,
        FIRST_NIGHT_ESCALATION,
        `The hour-by-hour guide for the first three days is on ${pet.name}'s plan.`,
      ],
    })
  }

  // ── A vaccination window opening: once, in the days after it opens ───────
  const vacc = vaccineState(pet, now)
  if (vacc.visible) {
    for (const d of vacc.dueNow) {
      const opened = now.getTime() - d.windowOpens.getTime()
      if (opened < 0 || opened > 3 * DAY) continue
      out.push({
        key: `vaccine:${d.dose.id}`,
        kind: 'vaccine',
        subject: `Around now is when ${pet.name}'s ${d.vaccine.label} (${d.dose.label.toLowerCase()}) is usually given`,
        lines: [
          `Your vet sets the schedule, not us — brands, local disease and the law all differ. This is a reminder to check with them and book.`,
          `If ${pet.name} has already had it, record it in the health file and we will stop mentioning it.`,
        ],
      })
    }
  }

  // ── Two weeks of the easy part left ──────────────────────────────────────
  const pass = passportState(pet, now)
  if (pass.visible && pass.window === 'open' && pass.weeksLeft === 2) {
    out.push({
      key: 'passport-two-weeks',
      kind: 'passport',
      subject: `Two weeks of the easy part left for ${pet.name}`,
      lines: [
        `Until about ${WINDOW_WEEKS[pet.species].closes} weeks old, a ${young} accepts new things far more readily than they ever will again. The passport in ${pet.name}'s health file has dozens of small ideas.`,
        `Nothing is required, and a frightened ${young} has not been socialised — they have been frightened. Go further away, make it smaller, and try again another day.`,
      ],
    })
  }

  // ── The yearly check ─────────────────────────────────────────────────────
  if (reviewDue(pet, now)) {
    out.push({
      key: `review:${now.getUTCFullYear()}`,
      kind: 'review',
      subject: `A year with ${pet.name}`,
      lines: [
        `Once a year we ask about the handful of things that actually change — shape, anything diagnosed, how much ${pet.name} moves, teeth. Every question is optional, and "still true" is the most common answer.`,
      ],
    })
  }

  // ── Gotcha Day: on the day, or the day after ─────────────────────────────
  const g = gotchaState(pet, now)
  if (g.active && g.daysSince <= 1) {
    out.push({
      key: `gotcha:${g.years}`,
      kind: 'gotcha',
      subject: `${pet.name}'s Gotcha Day — ${g.years} ${g.years === 1 ? 'year' : 'years'} home`,
      lines: [`${g.years === 1 ? 'A year' : `${g.years} years`} since ${pet.name} came home. There is a card to share on ${pet.name}'s plan, if you would like one.`],
    })
  }

  return out
}
