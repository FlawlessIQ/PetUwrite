import { describe, expect, it } from 'vitest'
import { firstNightState, FIRST_NIGHT_HOURS, hoursHomeLine } from './firstNight'
import { FIRST_NIGHT_BLOCKS, FIRST_NIGHT_ESCALATION } from '../data/firstNight'
import type { PetProfile } from '../data/types'

const NOW = new Date('2026-09-23T12:00:00Z')
const hoursAgo = (h: number) => new Date(NOW.getTime() - h * 3_600_000).toISOString()
const weeksOld = (w: number) =>
  new Date(NOW.getTime() - w * 7 * 86_400_000).toISOString().slice(0, 10)

const pup = (over: Partial<PetProfile> = {}): PetProfile => ({
  id: 'p',
  name: 'Scout',
  species: 'dog',
  breedId: 'labrador-retriever',
  birthDate: weeksOld(9),
  sex: 'female',
  weightLb: 0,
  conditionIds: [],
  knownSince: hoursAgo(2),
  ...over,
})

describe('when First-Night Mode is on', () => {
  it('is on for a nine-week-old who came home two hours ago', () => {
    const s = firstNightState(pup(), NOW)
    expect(s.active).toBe(true)
    expect(s.current?.id).toBe('arrival')
  })

  it('is off for a pet over twelve weeks, however recently they arrived', () => {
    const s = firstNightState(pup({ birthDate: weeksOld(20) }), NOW)
    expect(s.active).toBe(false)
    expect(s.reason).toBe('too-old')
  })

  it('is off after seventy-two hours', () => {
    const s = firstNightState(pup({ knownSince: hoursAgo(FIRST_NIGHT_HOURS + 1) }), NOW)
    expect(s.active).toBe(false)
    expect(s.reason).toBe('over-72-hours')
  })

  it('is off when we do not know when they arrived', () => {
    const s = firstNightState(pup({ knownSince: undefined }), NOW)
    expect(s.active).toBe(false)
    expect(s.reason).toBe('unknown-arrival')
  })

  it('treats a clock that went backwards as hour zero rather than showing nothing', () => {
    // Somebody is standing in their hallway with a puppy. A device-time change
    // is not a reason to show them an empty screen.
    const s = firstNightState(pup({ knownSince: hoursAgo(-5) }), NOW)
    expect(s.active).toBe(true)
    expect(s.current?.id).toBe('arrival')
  })
})

describe('which block', () => {
  const at = (h: number) => firstNightState(pup({ knownSince: hoursAgo(h) }), NOW).current?.id

  it('walks through the seventy-two hours in order', () => {
    expect(at(1)).toBe('arrival')
    expect(at(5)).toBe('evening')
    expect(at(10)).toBe('night')
    expect(at(18)).toBe('morning')
    expect(at(30)).toBe('day-two')
    expect(at(60)).toBe('day-three')
  })

  it('covers every hour with exactly one block, leaving no gap at 2am', () => {
    for (let h = 0; h < FIRST_NIGHT_HOURS; h++) {
      const s = firstNightState(pup({ knownSince: hoursAgo(h + 0.5) }), NOW)
      expect(s.current, `hour ${h} has no block`).not.toBeNull()
    }
  })

  it('shows what is still to come, so somebody awake at 3am can read ahead', () => {
    const s = firstNightState(pup({ knownSince: hoursAgo(1) }), NOW)
    expect(s.upcoming.length).toBeGreaterThan(3)
    expect(s.upcoming.every((b) => b.from > s.hoursHome)).toBe(true)
  })

  it('gives a kitten the cat blocks and never the dog ones', () => {
    const s = firstNightState(
      pup({ species: 'cat', breedId: 'domestic-shorthair', knownSince: hoursAgo(10) }),
      NOW,
    )
    expect(s.current?.species).toBe('cat')
    expect(s.current?.body).toMatch(/room/i)
    expect(s.upcoming.every((b) => b.species === 'cat')).toBe(true)
  })
})

describe('the content itself', () => {
  it('covers both species across the whole window with no overlap', () => {
    for (const species of ['dog', 'cat'] as const) {
      const blocks = FIRST_NIGHT_BLOCKS.filter((b) => b.species === species).sort(
        (a, b) => a.from - b.from,
      )
      expect(blocks[0].from).toBe(0)
      expect(blocks[blocks.length - 1].to).toBe(FIRST_NIGHT_HOURS)
      for (let i = 1; i < blocks.length; i++) {
        expect(blocks[i].from, `${species} gap or overlap`).toBe(blocks[i - 1].to)
      }
    }
  })

  it('never diagnoses, treats, or names a drug (invariant 4)', () => {
    // The surface talks to somebody at 2am. It must route to a vet, never
    // stand in for one.
    const blob = FIRST_NIGHT_BLOCKS.map((b) => `${b.body} ${b.doNow.join(' ')} ${b.normal}`).join(' ')
    expect(blob).not.toMatch(
      /\b(diagnos|prescrib|dose|dosage|mg\b|ml\b|antibiotic|paracetamol|ibuprofen|metacam|treat(ment)? for)\b/i,
    )
  })

  it('tells somebody what is normal, in every block', () => {
    // The failure mode of a 2am surface is panic at something ordinary.
    for (const b of FIRST_NIGHT_BLOCKS) {
      expect(b.normal.length, b.id).toBeGreaterThan(20)
      expect(b.doNow.length, b.id).toBeGreaterThanOrEqual(3)
    }
  })

  it('carries one escalation list, worded identically everywhere', () => {
    // These signs mean the same thing at 3am on night one as at noon on day
    // three; varying the wording would imply a variation in urgency.
    expect(FIRST_NIGHT_ESCALATION).toMatch(/call a vet now/i)
    expect(FIRST_NIGHT_ESCALATION).toMatch(/none of these are settling problems/i)
    for (const sign of ['vomiting', 'breathing', 'collapse', 'seizure', 'gums']) {
      expect(FIRST_NIGHT_ESCALATION.toLowerCase(), sign).toContain(sign)
    }
  })

  it('does not promise a longer life anywhere', () => {
    const blob = FIRST_NIGHT_BLOCKS.map((b) => `${b.title} ${b.body}`).join(' ')
    expect(blob).not.toMatch(/live longer|longer life|extra years|add years/i)
  })
})

describe('how long they have been home', () => {
  it('agrees with itself in the first half hour (UAT K4: "about 1 hours")', () => {
    expect(hoursHomeLine('Bruno', 0)).toBe('Bruno has been home about 1 hour.')
    expect(hoursHomeLine('Bruno', 0.3)).toBe('Bruno has been home about 1 hour.')
    expect(hoursHomeLine('Bruno', 1.4)).toBe('Bruno has been home about 1 hour.')
  })

  it('is plural from two', () => {
    expect(hoursHomeLine('Bruno', 1.6)).toBe('Bruno has been home about 2 hours.')
    expect(hoursHomeLine('Bruno', 47)).toBe('Bruno has been home about 47 hours.')
  })
})
