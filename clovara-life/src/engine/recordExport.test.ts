import { describe, expect, it } from 'vitest'
import { aboutRows, recordExport, RECORD_FORMAT } from './recordExport'
import { DEMO_PETS } from '../data/demoPets'
import type { PetProfile } from '../data/types'

const NOW = new Date('2026-09-30T08:00:00Z')

const bruno: PetProfile = {
  id: 'pet-bruno',
  name: 'Bruno',
  species: 'dog',
  breedId: 'labrador-retriever',
  birthDate: '2016-03-14',
  sex: 'male',
  neutered: true,
  neuterAgeBand: '6-11m',
  weightLb: 74,
  conditionIds: ['hip-dysplasia'],
  conditionsReviewed: true,
  dental: 'weekly',
  knownSince: '2016-05-20T00:00:00.000Z',
  lastReviewedAt: '2026-05-20T00:00:00.000Z',
  lastReviewedRange: { low: 11.5, high: 13 },
  vaccineRecords: [{ doseId: 'dog-dhp-1', givenOn: '2016-05-02' }],
  medications: [
    {
      id: 'm1',
      name: 'Joint tablet',
      amount: 'Half a tablet',
      frequency: 'Once a day',
      startedOn: '2026-01-04',
      given: ['2026-09-29', '2026-09-28'],
    },
  ],
  socialStamps: ['p-child'],
  lumps: [
    {
      id: 'l1',
      location: 'Left shoulder',
      firstSeen: '2026-08-01',
      note: 'Soft, moves <under> the skin',
      photos: [
        { url: 'https://example.test/p.jpg', fullPath: 'x', takenAt: '2026-08-01T10:00:00Z', sizeReference: 'a coin' },
        { url: 'javascript:alert(1)', fullPath: 'y', takenAt: '2026-09-01T10:00:00Z', sizeReference: null },
      ],
    },
  ],
  careNotes: { feeding: 'Two scoops, 7am & 6pm', vetPhone: '555 0100', quirks: '' },
}

describe('recordExport', () => {
  const files = recordExport(bruno, NOW)

  it('names the files after the pet', () => {
    expect(files.baseName).toBe('bruno-clovara-record')
    expect(recordExport({ ...bruno, name: 'Señor Wiggles!' }, NOW).baseName).toBe(
      'se-or-wiggles-clovara-record',
    )
  })

  it('keeps every field in the data copy, as held', () => {
    const data = JSON.parse(files.json)
    expect(data.format).toBe(RECORD_FORMAT)
    expect(data.version).toBe(1)
    expect(data.exportedAt).toBe(NOW.toISOString())
    expect(data.pet).toEqual(bruno)
  })

  it('reads as a record a person can keep', () => {
    const h = files.html
    expect(h).toContain('Everything on record for Bruno')
    expect(h).toContain('Labrador')
    expect(h).toContain('Hip dysplasia')
    expect(h).toContain('Joint tablet')
    expect(h).toContain('Doses ticked off (2)')
    expect(h).toContain('Left shoulder')
    expect(h).toContain('next to a coin')
    expect(h).toContain('11.5 to 13')
    expect(h).toContain('A calm, gentle child')
    expect(h).toContain('Nothing was sent anywhere')
  })

  it('escapes what the owner typed', () => {
    expect(files.html).toContain('moves &lt;under&gt; the skin')
    expect(files.html).toContain('Two scoops, 7am &amp; 6pm')
    expect(files.html).not.toContain('<under>')
  })

  it('never writes a link a saved file should not follow', () => {
    expect(files.html).toContain('src="https://example.test/p.jpg"')
    expect(files.html).not.toContain('javascript:')
  })

  it('leaves out empty notes and says nothing about sections with nothing in them', () => {
    expect(files.html).not.toContain('Quirks')
    expect(recordExport({ ...bruno, lumps: [] }, NOW).html).not.toContain('Lump diary')
  })

  it('mentions a stored range only when there is one', () => {
    expect(files.html).toContain('apart from the range at the last yearly check')
    expect(recordExport({ ...bruno, lastReviewedRange: undefined }, NOW).html).not.toContain(
      'last yearly check',
    )
  })
})

describe('unanswered stays unanswered', () => {
  const sparse: PetProfile = {
    id: 'p',
    name: 'Pip',
    species: 'cat',
    breedId: 'domestic-shorthair',
    birthDate: '2026-06-01',
    birthDateApprox: true,
    sex: 'female',
    weightLb: 0,
    conditionIds: [],
  }

  it('says "Not asked yet" rather than the engine default', () => {
    const rows = Object.fromEntries(aboutRows(sparse))
    expect(rows.Neutered).toBe('Not asked yet')
    expect(rows.Weight).toBe('Not asked yet')
    expect(rows.Exercise).toBe('Not asked yet')
    expect(rows['Goes outside']).toBe('Not asked yet')
    expect(rows.Born).toMatch(/\(estimated\)$/)
    expect(recordExport(sparse, NOW).html).toContain('Not asked yet.')
  })

  it('tells "none" apart from "never asked"', () => {
    expect(recordExport({ ...sparse, conditionsReviewed: true }, NOW).html).toContain(
      'None that you know of.',
    )
  })
})

describe('the demo pets', () => {
  it('each export without throwing', () => {
    for (const pet of DEMO_PETS) {
      const f = recordExport(pet, NOW)
      expect(f.html).toContain(`Everything on record for ${pet.name}`)
      expect(JSON.parse(f.json).pet.id).toBe(pet.id)
    }
  })
})
