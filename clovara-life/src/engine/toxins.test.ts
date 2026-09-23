import { describe, expect, it } from 'vitest'
import { bandFor, findToxins, toxinsFor, NULL_PLACES_PROVIDER, NO_PLACES_COPY } from './toxins'
import {
  POISON_LINES,
  TOXINS,
  TOXIN_DISCLAIMER,
  TOXIN_NEVER_DIY,
  TOXIN_PRIMARY_INSTRUCTION,
  TOXIN_TAKE_WITH_YOU,
} from '../data/toxins'
import type { PetProfile } from '../data/types'

const pet = (over: Partial<PetProfile> = {}): PetProfile => ({
  id: 'p',
  name: 'Scout',
  species: 'dog',
  breedId: 'labrador-retriever',
  birthDate: '2021-04-02',
  sex: 'female',
  weightLb: 66, // ~30kg
  conditionIds: [],
  ...over,
})

const toxin = (id: string) => TOXINS.find((t) => t.id === id)!

describe('the content', () => {
  it('NEVER tells anybody to make an animal vomit', () => {
    // The single most important assertion in this file. Inducing vomiting at
    // home injures and kills animals, and people reach for it because the
    // internet told them to.
    // TOXIN_NEVER_DIY is excluded from the blob and asserted separately: it is
    // the prohibition, and it necessarily contains the phrase it prohibits.
    const blob = [
      ...TOXINS.map((t) => `${t.name} ${t.why} ${t.signs}`),
      TOXIN_PRIMARY_INSTRUCTION,
      TOXIN_TAKE_WITH_YOU,
      TOXIN_DISCLAIMER,
    ].join(' ')
    expect(blob).not.toMatch(
      /\b(induce vomiting|make (them|him|her) (sick|vomit)|hydrogen peroxide|salt water|syrup of ipecac)\b/i,
    )
    // And says so explicitly, as a prohibition rather than an instruction.
    expect(TOXIN_NEVER_DIY).toMatch(/^do not try to make them sick/i)
    expect(TOXIN_NEVER_DIY).not.toMatch(/hydrogen peroxide|salt water/i)
  })

  it('never renders a milligram threshold as advice', () => {
    // SPEC §6.5: banding only. Thresholds exist to compute a band and are not
    // for reading — an owner given a number will try to decide for themselves.
    for (const t of TOXINS) {
      expect(`${t.why} ${t.signs}`, t.id).not.toMatch(/\d+\s*(mg|mg\/kg|milligram)/i)
    }
  })

  it('treats grapes, xylitol and lilies as having no safe dose', () => {
    for (const id of ['grapes', 'xylitol', 'lily-cat']) {
      expect(toxin(id).alwaysCall, id).toBe(true)
      expect(toxin(id).thresholds, id).toBeUndefined()
    }
  })

  it('gives a cat the lily and never gives one to a dog', () => {
    expect(toxinsFor('cat').some((t) => t.id === 'lily-cat')).toBe(true)
    expect(toxinsFor('dog').some((t) => t.id === 'lily-cat')).toBe(false)
  })

  it('says the packet matters more than the amount', () => {
    expect(TOXIN_TAKE_WITH_YOU).toMatch(/packet|wrapper|photograph/i)
    expect(toxin('rodenticide').why).toMatch(/photograph/i)
  })

  it('tells somebody to ring before signs appear', () => {
    expect(TOXIN_PRIMARY_INSTRUCTION).toMatch(/do not wait for signs/i)
  })

  it('says the poison lines charge, rather than letting somebody find out', () => {
    expect(POISON_LINES.length).toBeGreaterThanOrEqual(3)
    for (const line of POISON_LINES) {
      expect(line.tel, line.id).toMatch(/^\+\d{8,}$/)
      expect(line.note, line.id).toMatch(/fee/i)
    }
  })

  it('never implies the call is optional', () => {
    expect(TOXIN_DISCLAIMER).toMatch(/if you are not sure, ring/i)
    expect(TOXIN_DISCLAIMER).toMatch(/nobody minds the call/i)
  })
})

describe('banding', () => {
  it('calls now for anything with no safe dose, whatever the numbers say', () => {
    const r = bandFor(toxin('grapes'), pet({ weightLb: 200 }), { grams: 0.1 })
    expect(r.band).toBe('call-now')
    expect(r.escalatedForUncertainty).toBe(false)
  })

  it('escalates when we do not know the weight', () => {
    // Cost of a false call-now: somebody's evening. Cost of a false monitor: an
    // animal.
    const r = bandFor(toxin('chocolate'), pet({ weightLb: 0 }), { formId: 'milk', grams: 5 })
    expect(r.band).toBe('call-now')
    expect(r.escalatedForUncertainty).toBe(true)
    expect(r.because).toMatch(/do not know what they weigh/i)
  })

  it('escalates when we do not know the amount or the kind', () => {
    expect(bandFor(toxin('chocolate'), pet(), { formId: 'milk' }).band).toBe('call-now')
    expect(bandFor(toxin('chocolate'), pet(), { grams: 50 }).band).toBe('call-now')
    expect(bandFor(toxin('chocolate'), pet(), {}).escalatedForUncertainty).toBe(true)
  })

  it('bands chocolate by how dark it is, not just how much', () => {
    // 30kg dog. The same 40g is trivial as white chocolate and serious as
    // baking chocolate.
    const p = pet({ weightLb: 66 })
    expect(bandFor(toxin('chocolate'), p, { formId: 'white', grams: 40 }).band).toBe('monitor')
    expect(bandFor(toxin('chocolate'), p, { formId: 'baking', grams: 100 }).band).toBe('call-now')
  })

  it('bands the same chocolate differently for a small dog and a big one', () => {
    const big = pet({ weightLb: 132 }) // 60kg
    const small = pet({ weightLb: 11 }) // 5kg
    const g = { formId: 'dark', grams: 50 }
    expect(bandFor(toxin('chocolate'), big, g).band).not.toBe('call-now')
    expect(bandFor(toxin('chocolate'), small, g).band).toBe('call-now')
  })

  it('escalates below the published clinical threshold, never above it', () => {
    // Signs from chocolate are described from around 20 mg/kg. Our call-now sits
    // at 20 and vet-today at 8, so we are asking people to ring before the
    // literature says anything happens. That is the intended bias.
    const t = toxin('chocolate')
    expect(t.thresholds!.callNow).toBeLessThanOrEqual(20)
    expect(t.thresholds!.vetToday).toBeLessThan(t.thresholds!.callNow)
  })

  it('never says a small amount is safe', () => {
    const r = bandFor(toxin('chocolate'), pet(), { formId: 'white', grams: 1 })
    expect(r.band).toBe('monitor')
    expect(r.because).toMatch(/not a clearance/i)
    expect(r.because).not.toMatch(/\b(safe|fine|no need|nothing to worry)\b/i)
  })
})

describe('search', () => {
  it('finds a grape from the word people type', () => {
    expect(findToxins('raisin', 'dog').map((t) => t.id)).toContain('grapes')
    expect(findToxins('mince pie', 'dog').map((t) => t.id)).toContain('grapes')
  })

  it('finds painkillers by brand as well as by drug', () => {
    for (const q of ['nurofen', 'tylenol', 'paracetamol']) {
      expect(findToxins(q, 'dog').map((t) => t.id), q).toContain('nsaid')
    }
  })

  it('finds xylitol from peanut butter, which is how people meet it', () => {
    expect(findToxins('peanut butter', 'dog').map((t) => t.id)).toContain('xylitol')
  })

  it('returns everything for an empty query rather than nothing', () => {
    expect(findToxins('', 'dog').length).toBe(toxinsFor('dog').length)
  })

  it('never returns a cat toxin to a dog owner', () => {
    expect(findToxins('lily', 'dog')).toHaveLength(0)
    expect(findToxins('lily', 'cat').map((t) => t.id)).toContain('lily-cat')
  })
})

describe('the emergency-vet lookup seam', () => {
  it('is honest that it cannot search, rather than returning nothing found', () => {
    // At 2am "no results" reads as "there is nowhere open".
    expect(NULL_PLACES_PROVIDER.available).toBe(false)
    expect(NO_PLACES_COPY).toMatch(/cannot look up/i)
    expect(NO_PLACES_COPY).toMatch(/emergency vet near me/i)
    expect(NO_PLACES_COPY).not.toMatch(/no results|none found|nothing nearby/i)
  })
})
