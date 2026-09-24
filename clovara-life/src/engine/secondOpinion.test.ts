import { describe, expect, it } from 'vitest'
import { questionsFor } from './secondOpinion'
import { NOT_A_VERDICT, PRICE_NOTE, QUESTIONS } from '../data/secondOpinion'
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
const ask = (said: string, p: PetProfile = pet()) =>
  questionsFor(said, p, project(p, { now: NOW }))

describe('the line it will not cross', () => {
  it('NEVER suggests the recommendation is wrong', () => {
    const blob = QUESTIONS.map((q) => `${q.text} ${q.because}`).join(' ')
    expect(blob).not.toMatch(
      /\b(unnecessary|not needed|do not need|overpriced|too expensive|rip.?off|avoid|refuse|push back|talk them out)\b/i,
    )
  })

  it('never offers a clinical view of its own', () => {
    const blob = QUESTIONS.map((q) => `${q.text} ${q.because}`).join(' ')
    // Scoped to US asserting something. "How likely is it for a pet like
    // mine?" is a question TO the vet and a bare /likely/ flagged it.
    expect(blob).not.toMatch(
      /\b(we think|we would say|we believe|in our view|it is probably|it is likely|sounds like|we can tell|our assessment)\b/i,
    )
  })

  it('says outright that these are questions and not doubts', () => {
    expect(NOT_A_VERDICT).toMatch(/questions, not doubts/i)
    expect(NOT_A_VERDICT).toMatch(/nothing here suggests the recommendation is wrong/i)
    expect(NOT_A_VERDICT).toMatch(/have not examined your pet/i)
  })

  it('refuses to judge the price, and explains why', () => {
    expect(PRICE_NOTE).toMatch(/do not tell you whether the price is fair/i)
    expect(PRICE_NOTE).toMatch(/top of a range may be the better practice/i)
  })

  it('every question is one a good vet would be pleased to be asked', () => {
    // The test of the whole list. Anything designed to catch somebody out fails
    // it, and "would you mind if I got a second opinion" is asked openly on
    // purpose rather than arranged behind their back.
    const openSecond = QUESTIONS.find((q) => q.id === 'second-opinion-referral')!
    expect(openSecond.because).toMatch(/behind their back makes the next conversation harder/i)
  })
})

describe('which questions come back', () => {
  it('always asks what happens if you do nothing, first', () => {
    expect(ask('they want to do a dental').questions[0].id).toBe('do-nothing')
  })

  it('always covers alternatives, urgency, recovery and what is included', () => {
    const ids = ask('a procedure').questions.map((q) => q.id)
    for (const id of ['alternatives', 'urgency', 'recovery', 'included', 'risks', 'success']) {
      expect(ids, id).toContain(id)
    }
  })

  it('adds the anaesthetic question when surgery is mentioned', () => {
    expect(ask('they have recommended surgery').questions.map((q) => q.id)).toContain('anaesthetic')
    expect(ask('a course of tablets').questions.map((q) => q.id)).not.toContain('anaesthetic')
  })

  it('adds pre-authorisation when insurance comes up', () => {
    expect(ask('will my insurance cover this').questions.map((q) => q.id)).toContain(
      'insurance-preauth',
    )
  })

  it('adds the open second-opinion question when somebody is unsure', () => {
    expect(ask('I am not sure about this, it is a big decision').questions.map((q) => q.id)).toContain(
      'second-opinion-referral',
    )
  })

  it('is stable — the same words give the same questions', () => {
    const a = ask('surgery on her cruciate').questions.map((q) => q.id)
    const b = ask('surgery on her cruciate').questions.map((q) => q.id)
    expect(a).toEqual(b)
  })

  it('returns the universal set even for an empty message', () => {
    expect(ask('').questions.length).toBeGreaterThanOrEqual(8)
  })
})

describe('what it raises from the record', () => {
  it('names a declared condition without judging its relevance', () => {
    const r = ask('they want to do surgery', pet({ conditionIds: ['hip-dysplasia'] }))
    expect(r.fromTheRecord.join(' ')).toMatch(/hip dysplasia/i)
    expect(r.fromTheRecord.join(' ')).toMatch(/worth making sure they know/i)
    // Not "this is relevant to your surgery" — we have not judged that.
    expect(r.fromTheRecord.join(' ')).not.toMatch(/\b(relevant to|affects|because of|complicat)\b/i)
  })

  it('surfaces current medication, which people forget in the room', () => {
    const r = ask('surgery', pet({ careNotes: { meds: 'Half a joint tablet with breakfast' } }))
    expect(r.fromTheRecord.join(' ')).toMatch(/Half a joint tablet/)
  })

  it('mentions age for an older animal', () => {
    expect(ask('surgery', pet({ birthDate: '2015-04-02' })).fromTheRecord.join(' ')).toMatch(
      /worth saying out loud/i,
    )
    expect(ask('surgery', pet()).fromTheRecord.join(' ')).not.toMatch(/worth saying out loud/i)
  })

  it('says nothing about a pet with nothing on record', () => {
    expect(ask('surgery', pet()).fromTheRecord).toHaveLength(0)
  })
})
