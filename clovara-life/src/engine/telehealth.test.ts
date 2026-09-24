import { describe, expect, it } from 'vitest'
import { asksForAVet, routeToVet, TELEHEALTH_AVAILABLE } from './telehealth'

describe('recognising the ask', () => {
  it('catches the ways people ask for a vet', () => {
    for (const said of [
      'Can I speak to a vet?',
      'I want to talk to a vet about this',
      'book an appointment please',
      'is there a video vet',
      'can you get me a vet',
      'I need a vet tonight',
      'how do I find a vet near me',
      'can I get a second opinion',
    ]) {
      expect(asksForAVet(said), said).toBe(true)
    }
  })

  it('does not fire on ordinary mentions of the word', () => {
    for (const said of [
      'The vet said he was fine last year',
      'his vet records are in the app',
      'when is his next vet visit due',
    ]) {
      expect(asksForAVet(said), said).toBe(false)
    }
  })

  it('survives punctuation and capitals', () => {
    expect(asksForAVet('CAN I SPEAK TO A VET?!')).toBe(true)
  })
})

describe('what it says with no partner', () => {
  it('is honest that there is no partner', () => {
    expect(TELEHEALTH_AVAILABLE).toBe(false)
    const r = routeToVet('Scout')
    expect(r.available).toBe(false)
    expect(r.headline).toMatch(/cannot put you through/i)
    expect(r.body).toMatch(/no video vet behind Clovara yet/i)
  })

  it('does not promise the feature is coming', () => {
    // A roadmap promise to somebody who needs a vet tonight is worthless.
    const r = routeToVet('Scout')
    const blob = `${r.headline} ${r.body} ${r.steps.join(' ')}`
    expect(blob).not.toMatch(/\b(soon|coming|shortly|we are working on|in future|later this)\b/i)
  })

  it('leads with the summary, which is the thing that actually helps', () => {
    const r = routeToVet('Scout')
    expect(r.steps[0]).toMatch(/summary/i)
    expect(r.steps[0]).toContain('Scout')
  })

  it('tells somebody how to reach a vet out of hours', () => {
    const r = routeToVet('Scout')
    expect(r.steps.join(' ')).toMatch(/out of hours/i)
    expect(r.steps.join(' ')).toMatch(/emergency vet|poison line/i)
  })

  it('never suggests waiting', () => {
    const r = routeToVet('Scout')
    // Targeted at suggestions TO wait. "If it cannot wait" is the opposite,
    // and a bare /wait/ flagged it.
    expect(r.steps.join(' ')).not.toMatch(
      /\b(you can wait|it can wait|wait until|wait and see|hold off|monitor for now|see how (he|she|they) go)\b/i,
    )
  })
})
