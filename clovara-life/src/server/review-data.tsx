/**
 * Everything the review packs quote, gathered from the code that renders it
 * (UNBLOCKED-BUILD-PLAN UB1–UB3). Bundled and run by scripts/review-packs.mjs;
 * never shipped to the browser. Copy that lives in a component is rendered to
 * text, so the packs quote what a person actually sees.
 */
import { renderToStaticMarkup } from 'react-dom/server'
import type { ReactElement } from 'react'
import * as red from '../data/redFlags'
import * as tox from '../data/toxins'
import * as fn from '../data/firstNight'
import * as sen from '../data/senior'
import * as vax from '../data/vaccines'
import * as att from '../data/attach'
import { POISON_LINES } from '../data/poisonLines'
import { COVERAGE_DISCLAIMER } from '../data/coverage'
import { REWARDS_DISCLAIMER } from '../data/rewards'
import { FRONT_DOOR } from '../data/frontDoor'
import { DEMO_PETS } from '../data/demoPets'
import { NO_PLACES_COPY } from '../engine/places'
import { momentsDue } from '../engine/moments'
import { calendarEvents } from '../engine/calendar'
import { project } from '../engine/project'
import { DataCovenant } from '../components/DataCovenant'
import { Shop } from '../components/Shop'
import { SaveNudge } from '../components/SaveNudge'
import type { PetProfile } from '../data/types'

/** Fixed, so the packs are identical every time they are generated. */
export const NOW = new Date('2026-09-30T08:00:00Z')

export function text(el: ReactElement): string[] {
  return renderToStaticMarkup(el)
    .replace(/<(br|\/p|\/li|\/h[1-6]|\/div|\/section|\/button|\/a|\/label)[^>]*>/g, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&amp;/g, '&').replace(/&rsquo;/g, '’').replace(/&ldquo;/g, '“').replace(/&rdquo;/g, '”')
    .replace(/&#x27;/g, "'").replace(/&quot;/g, '"').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .split('\n').map((l) => l.trim()).filter(Boolean)
}

const ago = (days: number) => new Date(NOW.getTime() - days * 86_400_000).toISOString()
const pup = (over: Partial<PetProfile>): PetProfile => ({
  id: 'bruno', name: 'Bruno', species: 'dog', breedId: 'labrador-retriever', sex: 'male',
  weightLb: 0, conditionIds: [], birthDate: ago(71).slice(0, 10), knownSince: ago(30), ...over,
})

/** One sample pet per kind of moment email, so every one is shown. */
export const MOMENT_SAMPLES: { label: string; pet: PetProfile }[] = [
  { label: 'The first night (a puppy home since yesterday)', pet: pup({ knownSince: new Date(NOW.getTime() - 20 * 3_600_000).toISOString() }) },
  { label: 'A vaccination window opening (ten weeks old)', pet: pup({}) },
  { label: 'Two weeks of the socialisation window left', pet: pup({ birthDate: ago(12 * 7 + 3).slice(0, 10) }) },
  { label: 'The yearly check', pet: pup({ birthDate: '2022-03-01', knownSince: '2022-05-10T12:00:00Z' }) },
  { label: 'Gotcha Day', pet: pup({ birthDate: '2021-01-01', knownSince: '2023-09-30T08:00:00Z', lastReviewedAt: ago(20) }) },
]

export function reviewData() {
  const max = DEMO_PETS[0]
  const bruno = pup({})
  return {
    red: { flags: red.RED_FLAGS, headline: red.RED_FLAG_HEADLINE, body: red.RED_FLAG_BODY, noFlagHeadline: red.NO_FLAG_HEADLINE, noFlagBody: red.NO_FLAG_BODY },
    tox: { entries: tox.TOXINS, primary: tox.TOXIN_PRIMARY_INSTRUCTION, neverDiy: tox.TOXIN_NEVER_DIY, takeWithYou: tox.TOXIN_TAKE_WITH_YOU, disclaimer: tox.TOXIN_DISCLAIMER, noPlaces: NO_PLACES_COPY, lines: POISON_LINES },
    firstNight: { blocks: fn.FIRST_NIGHT_BLOCKS, escalation: fn.FIRST_NIGHT_ESCALATION, footer: fn.FIRST_NIGHT_FOOTER },
    senior: { adaptations: sen.ADAPTATIONS, worthMentioning: sen.WORTH_MENTIONING, opening: sen.SENIOR_OPENING, noScale: sen.NO_SCALE_NOTE, mention: sen.MENTION_NOTE },
    vaccines: { core: vax.CORE_VACCINES, doses: vax.VACCINE_DOSES, nonCore: vax.NON_CORE_TO_ASK, disclaimer: vax.VACCINE_DISCLAIMER, recordNote: vax.VACCINE_RECORD_NOTE },
    attach: { disclosures: att.DISCLOSURES, fraud: att.FRAUD_NOTICE, attestation: att.ATTESTATION, notLive: att.NOT_LIVE_NOTE, illustrative: att.ILLUSTRATIVE_LABEL, waiting: att.WAITING_PERIODS },
    disclaimers: { coverage: COVERAGE_DISCLAIMER, rewards: REWARDS_DISCLAIMER },
    frontDoor: FRONT_DOOR,
    covenant: text(<DataCovenant onClose={() => {}} />),
    shopMembership: text(<Shop pet={bruno} projection={project(bruno, { now: NOW })} member={false} busy={false} onStartTrial={() => {}} />)
      .filter((l) => /members|Membership is priced/i.test(l)),
    saveNudge: text(<SaveNudge pet={bruno} onKeep={() => {}} surface="life" />),
    moments: MOMENT_SAMPLES.map((s) => ({ label: s.label, moments: momentsDue(s.pet, NOW) })),
    calendar: calendarEvents(bruno, NOW),
    demoName: max.name,
  }
}
