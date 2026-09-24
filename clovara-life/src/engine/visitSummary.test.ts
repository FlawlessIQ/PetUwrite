import { describe, expect, it } from 'vitest'
import { buildVisitSummary, summaryAsText } from './visitSummary'
import { project } from './project'
import type { PetProfile } from '../data/types'

const NOW = new Date('2026-09-24T12:00:00Z')
const pet = (over: Partial<PetProfile> = {}): PetProfile => ({
  id: 'p',
  name: 'Scout',
  species: 'dog',
  breedId: 'labrador-retriever',
  birthDate: '2019-04-02',
  sex: 'female',
  weightLb: 68,
  conditionIds: [],
  ...over,
})
const summary = (p: PetProfile) => buildVisitSummary(p, project(p, { now: NOW }), NOW)
const allText = (p: PetProfile) => summaryAsText(summary(p))

describe('what it must never do', () => {
  it('NEVER includes the healthy-years projection', () => {
    // It is a planning number from breed medians. Beside real clinical facts,
    // in front of a clinician, it would read as a prognosis for this animal —
    // which it is not and which we cannot give.
    const t = allText(pet({ conditionIds: ['hip-dysplasia'] }))
    expect(t).not.toMatch(/healthy years/i)
    expect(t).not.toMatch(/\d+\.\d\s*–\s*\d+\.\d/)
  })

  it('says on the page why the projection is absent', () => {
    expect(summary(pet()).caveats.join(' ')).toMatch(/not a prognosis for this animal/i)
  })

  it('never interprets, concludes or suggests', () => {
    // Invariant 4 binds hardest in the one room where somebody qualified is
    // present. It reports; it does not conclude.
    const t = allText(pet({ conditionIds: ['hip-dysplasia'], bodyConditionScore: 5 }))
    expect(t).not.toMatch(
      /\b(consistent with|suggests|likely|probably|recommend|should be|consider|rule out|differential)\b/i,
    )
  })

  it('never names a drug or a dose', () => {
    const t = allText(pet({ careNotes: { meds: 'Half a tablet with breakfast' } }))
    expect(t).not.toMatch(/\b(\d+\s*(mg|ml)|BID|SID|q\d+h)\b/i)
  })
})

describe('what it must always do', () => {
  it('prints "not asked" rather than implying an answer', () => {
    // A vet reading "no conditions" would reasonably take it as a negative
    // history. "Not asked" is the truth.
    const t = allText(pet())
    expect(t).toMatch(/Not asked/)
    expect(t).toMatch(/not a negative history/i)
  })

  it('distinguishes "asked and told nothing" from "never asked"', () => {
    const neverAsked = summary(pet()).sections.find((s) => s.heading === 'Already on file')!
    const asked = summary(pet({ conditionsReviewed: true })).sections.find(
      (s) => s.heading === 'Already on file',
    )!
    expect(neverAsked.emptyNote).toMatch(/has not been put/i)
    expect(asked.emptyNote).toMatch(/reported nothing diagnosed/i)
    expect(asked.emptyNote).toMatch(/not a clinical negative history/i)
  })

  it('carries provenance on every line (invariant 8)', () => {
    const s = summary(pet({ activity: 'moderate', bodyConditionScore: 3 }))
    for (const section of s.sections) {
      for (const l of section.lines) {
        expect(['owner said', 'from a document', 'not asked'], `${l.label}`).toContain(l.told)
      }
    }
  })

  it('says everything came from an owner through an app, unverified', () => {
    const c = summary(pet()).caveats.join(' ')
    expect(c).toMatch(/reported by the owner/i)
    expect(c).toMatch(/examined or verified by a veterinarian/i)
    expect(c).toMatch(/not a medical record/i)
  })

  it('flags an estimated birthday as estimated', () => {
    expect(allText(pet({ birthDateApprox: true }))).toMatch(/birthday estimated, not known/i)
    expect(allText(pet())).toMatch(/born 2 April 2019/)
  })

  it('says the body condition is a silhouette pick, not a clinical BCS', () => {
    expect(allText(pet({ bodyConditionScore: 4 }))).toMatch(/not a clinical BCS/i)
  })

  it('says an empty vaccination list means nobody typed it in', () => {
    const v = summary(pet()).sections.find((s) => s.heading.startsWith('Vaccinations'))!
    expect(v.emptyNote).toMatch(/nobody typed it in/i)
    expect(v.emptyNote).toMatch(/not that nothing was given/i)
  })
})

describe('the content', () => {
  it('names declared conditions', () => {
    const t = allText(pet({ conditionIds: ['hip-dysplasia'] }))
    expect(t.toLowerCase()).toContain('hip dysplasia')
  })

  it('lists recorded vaccinations oldest first, with real dates', () => {
    const t = allText(
      pet({
        vaccineRecords: [
          { doseId: 'dog-dhp-2', givenOn: '2019-07-01' },
          { doseId: 'dog-dhp-1', givenOn: '2019-06-01' },
        ],
      }),
    )
    expect(t.indexOf('1 June 2019')).toBeLessThan(t.indexOf('1 July 2019'))
  })

  it('asks a cat about outdoor access and never a dog', () => {
    const catText = allText(pet({ species: 'cat', breedId: 'domestic-shorthair', outdoorAccess: 'indoor' }))
    expect(catText).toMatch(/Outdoor access/)
    expect(allText(pet())).not.toMatch(/Outdoor access/)
  })

  it('includes medication the owner wrote for a sitter', () => {
    expect(allText(pet({ careNotes: { meds: 'Half a tablet with breakfast' } }))).toMatch(
      /Half a tablet with breakfast/,
    )
  })

  it('produces text a practice system can take', () => {
    // The primary output. A vet's computer does not accept a screenshot, and an
    // owner reading aloud from a phone is what this replaces.
    const t = allText(pet({ conditionIds: ['hip-dysplasia'], activity: 'low' }))
    expect(t).toMatch(/^Scout — Labrador Retriever, 7 years old/)
    expect(t).toMatch(/WHO THEY ARE/)
    expect(t).toMatch(/NOTES/)
    expect(t.split('\n').length).toBeGreaterThan(15)
  })

  it('never crashes on a pet with nothing filled in', () => {
    const bare = summary(pet({ weightLb: 0 }))
    expect(bare.sections.length).toBeGreaterThan(3)
    expect(summaryAsText(bare)).toContain('Not asked')
  })
})
