import { describe, expect, it } from 'vitest'
import { classify, flagsFor } from './safety'
import {
  NO_FLAG_BODY,
  NO_FLAG_HEADLINE,
  RED_FLAGS,
  RED_FLAG_BODY,
} from '../data/redFlags'

const dog = (s: string) => classify(s, 'dog')
const cat = (s: string) => classify(s, 'cat')

describe('things that MUST escalate', () => {
  const mustEscalate: [string, 'dog' | 'cat'][] = [
    ['He collapsed in the garden and won\'t get up', 'dog'],
    ['She is struggling to breathe', 'dog'],
    ['his gums look blue', 'dog'],
    ['He had a seizure this morning', 'dog'],
    ['she has been fitting', 'cat'],
    ['My cat keeps going in and out of the litter tray and nothing is coming out', 'cat'],
    ['He keeps going to the litter tray and nothing is coming out', 'cat'],
    ['she is squatting and crying', 'cat'],
    ['he is straining to pee', 'cat'],
    ['His belly is swollen and he keeps retching', 'dog'],
    ['dry heaving and a hard belly', 'dog'],
    ['She was hit by a car', 'dog'],
    ['the dog next door attacked him', 'dog'],
    ['her gums are pale', 'cat'],
    ['he ate rat poison', 'dog'],
    ['She ate grapes off the counter', 'dog'],
    ['left in the car and now he is panting', 'dog'],
    ['her face is swollen and she has hives', 'dog'],
    ['My cat is panting', 'cat'],
    ['she has not eaten for two days', 'cat'],
    ['he cannot keep water down', 'dog'],
    ['there is blood in his stool', 'dog'],
    ['She is screaming and won\'t let me touch her', 'dog'],
    ['he scratched his eye', 'dog'],
  ]

  for (const [text, species] of mustEscalate) {
    it(`escalates: "${text.slice(0, 44)}"`, () => {
      const r = classify(text, species)
      expect(r.escalate, `did not escalate: ${text}`).toBe(true)
      expect(r.matched.length).toBeGreaterThan(0)
    })
  }
})

describe('the species distinctions that actually matter', () => {
  it('panting is an emergency in a cat and ordinary in a dog', () => {
    expect(cat('she is panting').escalate).toBe(true)
    expect(dog('she is panting after a run').escalate).toBe(false)
  })

  it('straining in the tray escalates for a cat', () => {
    expect(cat('he is straining to pee').escalate).toBe(true)
  })

  it('a swollen retching belly escalates for a dog', () => {
    expect(dog('swollen belly and dry heaving').escalate).toBe(true)
  })

  it('not eating escalates for a cat, where fasting itself is the danger', () => {
    expect(cat('she is not eating').escalate).toBe(true)
    expect(dog('he is not eating').escalate).toBe(false)
  })
})

describe('negation is deliberately NOT suppressed', () => {
  it('still escalates on a negated mention, and that is the intended trade', () => {
    // Suppressing here would mean "he is not breathing right" fails to
    // escalate. The wasted call is the acceptable error; the missed one is not.
    expect(dog('he has never had a seizure').escalate).toBe(true)
    expect(dog('no seizures, but he seems off').escalate).toBe(true)
  })

  it('and escalates on the phrasing that suppression would have broken', () => {
    expect(dog('he is not breathing right').escalate).toBe(true)
    expect(dog('no, seizure! what do I do').escalate).toBe(true)
  })
})

describe('what must NOT escalate', () => {
  it('ordinary worry does not', () => {
    for (const s of [
      'He seems a bit quiet today',
      'She has been scratching her ear',
      'What should I feed him',
      'When is his next vaccination due',
      'he is getting old',
    ]) {
      expect(dog(s).escalate, s).toBe(false)
    }
  })

  it('an empty message does not', () => {
    expect(dog('').escalate).toBe(false)
    expect(dog('   ').escalate).toBe(false)
  })
})

describe('matching', () => {
  it('survives punctuation, capitals and curly apostrophes', () => {
    expect(dog('HE COLLAPSED!!').escalate).toBe(true)
    expect(dog('he won’t get up').escalate).toBe(true)
    expect(dog("he won't get up").escalate).toBe(true)
  })

  it('reports what matched, so the page can show it back', () => {
    const r = dog('he collapsed and his gums are pale')
    expect(r.matched.map((m) => m.id).sort()).toEqual(['collapse', 'gums'])
  })

  it('counts what it considered, so "nothing matched" can be honest', () => {
    expect(dog('hello').consideredCount).toBe(flagsFor('dog').length)
  })
})

describe('the content', () => {
  it('describes signs an owner can see, never a diagnosis', () => {
    for (const f of RED_FLAGS) {
      expect(f.label, f.id).not.toMatch(
        /\b(obstruction|torsion|GDV|dysplasia|pancreatitis|lipidosis|anaphyla|syndrome)\b/i,
      )
    }
  })

  it('gives every flag a reason in plain words', () => {
    for (const f of RED_FLAGS) {
      expect(f.because.length, f.id).toBeGreaterThan(30)
      expect(f.phrases.length, f.id).toBeGreaterThan(0)
    }
  })

  it('NEVER reassures when nothing matched', () => {
    // The sentence the whole surface turns on. An owner who reads "sounds fine"
    // and goes to bed is the failure this exists to prevent.
    expect(NO_FLAG_HEADLINE).not.toMatch(/fine|okay|ok\b|no need|nothing wrong|not serious/i)
    expect(NO_FLAG_BODY).toMatch(/statement about our list, not about your pet/i)
    expect(NO_FLAG_BODY).toMatch(/plenty of serious things are not on it/i)
  })

  it('tells somebody to ring even when unsure', () => {
    expect(RED_FLAG_BODY).toMatch(/nobody minds the call/i)
    expect(RED_FLAG_BODY).toMatch(/out of hours/i)
  })
})
