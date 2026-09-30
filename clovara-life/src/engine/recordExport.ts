/**
 * "Download everything about Bruno" (BACKLOG UB12).
 *
 * The Data Covenant says an owner can ask for everything we hold on their pet.
 * This answers that for the pet record without an email to us: two files,
 * made on the device — a page a person can read and keep, and the same record
 * as data for another program. Pure: the clock is injected, nothing is sent.
 *
 * What it is NOT: a claim that nothing else exists. The Covenant's wording is
 * counsel's (UB12 changes none of it); this file says plainly what it holds.
 *
 * Unanswered stays unanswered. A question nobody was asked reads "Not asked
 * yet", never the default the engine uses in its place (DECISIONS 2026-09-26).
 */
import type { PetProfile } from '../data/types'
import { findBreed, KNOWN_CONDITIONS } from '../data/engine'
import { CORE_VACCINES, VACCINE_DOSES } from '../data/vaccines'
import { SOCIAL_STAMPS } from '../data/socialization'

export const RECORD_FORMAT = 'clovara-life.pet-record'
export const RECORD_VERSION = 1

export interface RecordFiles {
  /** File name without extension: `bruno-clovara-record`. */
  baseName: string
  html: string
  json: string
}

const NOT_ASKED = 'Not asked yet'

const LABELS = {
  sex: { male: 'Male', female: 'Female' },
  activity: { low: 'Low', moderate: 'Moderate', high: 'High' },
  dental: { daily: 'Daily', weekly: 'Weekly', rarely: 'Rarely' },
  diet: { measured: 'Measured meals', 'free-fed': 'Free fed', unsure: 'Not sure' },
  outdoor: { indoor: 'Indoor', 'indoor-outdoor': 'Both', outdoor: 'Outdoor' },
  neuterAge: {
    'under-6m': 'Under 6 months',
    '6-11m': '6 to 11 months',
    '12-23m': '12 to 23 months',
    '24m-plus': '2 years or older',
    unsure: 'Not sure',
  },
} as const

const CARE_NOTE_LABELS: Record<keyof NonNullable<PetProfile['careNotes']>, string> = {
  feeding: 'Feeding',
  meds: 'Medicines',
  quirks: 'Quirks',
  vetName: 'Vet',
  vetPhone: 'Vet’s number',
  emergencyName: 'Emergency contact',
  emergencyPhone: 'Emergency number',
}

function esc(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
}

/** Only links a browser should follow from a saved file: http(s) and inline images. */
function safeUrl(u: string | undefined): string | null {
  if (!u) return null
  return /^https:\/\//i.test(u) || /^data:image\/(png|jpe?g|webp|gif);/i.test(u) ? u : null
}

function day(iso: string | undefined): string {
  if (!iso) return ''
  const t = Date.parse(iso.length === 10 ? `${iso}T12:00:00Z` : iso)
  if (!Number.isFinite(t)) return iso
  return new Date(t).toLocaleDateString('en-GB', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    timeZone: 'UTC',
  })
}

function slug(name: string): string {
  return name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') || 'pet'
}

function pick<T extends Record<string, string>>(map: T, v: string | undefined): string {
  return v && v in map ? map[v as keyof T] : NOT_ASKED
}

/** The rows of "About", in reading order. Pure, and exported for the tests. */
export function aboutRows(pet: PetProfile): [string, string][] {
  const breed = findBreed(pet.breedId)
  const rows: [string, string][] = [
    ['Name', pet.name],
    ['Species', pet.species === 'dog' ? 'Dog' : 'Cat'],
    ['Breed', breed?.name ?? pet.breedId],
    ['Born', `${day(pet.birthDate)}${pet.birthDateApprox ? ' (estimated)' : ''}`],
    ['Sex', LABELS.sex[pet.sex] ?? pet.sex],
    ['Neutered', pet.neutered === true ? 'Yes' : pet.neutered === false ? 'No' : NOT_ASKED],
  ]
  if (pet.species === 'dog' && pet.neutered)
    rows.push(['Neutered at', pick(LABELS.neuterAge, pet.neuterAgeBand)])
  rows.push(
    ['Weight', pet.weightLb > 0 ? `${pet.weightLb} lb` : NOT_ASKED],
    ['Body condition', pet.bodyConditionScore ? `${pet.bodyConditionScore} of 5` : NOT_ASKED],
    ['Exercise', pick(LABELS.activity, pet.activity)],
    ['Teeth brushed', pick(LABELS.dental, pet.dental)],
    ['Feeding', pick(LABELS.diet, pet.diet)],
  )
  if (pet.species === 'cat') rows.push(['Goes outside', pick(LABELS.outdoor, pet.outdoorAccess)])
  if (pet.knownSince) rows.push(['With you since', day(pet.knownSince)])
  if (pet.lastReviewedAt) rows.push(['Last yearly check', day(pet.lastReviewedAt)])
  if (pet.lastReviewedRange)
    rows.push([
      'Healthy years, at that check',
      `${pet.lastReviewedRange.low} to ${pet.lastReviewedRange.high}`,
    ])
  if (pet.diedOn) rows.push(['Died', day(pet.diedOn)])
  return rows
}

function section(title: string, body: string): string {
  return `<section><h2>${esc(title)}</h2>${body}</section>`
}

function list(items: string[]): string {
  return `<ul>${items.map((i) => `<li>${i}</li>`).join('')}</ul>`
}

function renderHtml(pet: PetProfile, now: Date): string {
  const name = esc(pet.name)
  const parts: string[] = []

  parts.push(
    section(
      'About',
      `<table>${aboutRows(pet)
        .map(([k, v]) => `<tr><th scope="row">${esc(k)}</th><td>${esc(v)}</td></tr>`)
        .join('')}</table>`,
    ),
  )

  const conditions = pet.conditionIds.map(
    (id) => KNOWN_CONDITIONS.find((c) => c.id === id)?.name ?? id,
  )
  parts.push(
    section(
      'Already diagnosed',
      conditions.length
        ? list(conditions.map(esc))
        : `<p>${pet.conditionsReviewed ? 'None that you know of.' : NOT_ASKED + '.'}</p>`,
    ),
  )

  if (pet.vaccineRecords?.length) {
    const rows = [...pet.vaccineRecords]
      .sort((a, b) => a.givenOn.localeCompare(b.givenOn))
      .map((r) => {
        const dose = VACCINE_DOSES.find((d) => d.id === r.doseId)
        const vaccine = dose && CORE_VACCINES.find((v) => v.id === dose.vaccineId)
        const what = dose && vaccine ? `${vaccine.label}, ${dose.label.toLowerCase()}` : r.doseId
        return `${esc(what)} — ${esc(day(r.givenOn))}`
      })
    parts.push(
      section(
        'Vaccinations you recorded',
        `${list(rows)}<p class="note">Your own note of what was given. Your vet's record is the one that counts.</p>`,
      ),
    )
  }

  if (pet.medications?.length) {
    parts.push(
      section(
        'Medicines',
        pet.medications
          .map((m) => {
            const given = [...m.given].sort()
            const dates = given.length
              ? `<p class="note">Doses ticked off (${given.length}): ${given.map((g) => esc(day(g))).join(', ')}</p>`
              : ''
            return `<h3>${esc(m.name)}</h3><p>${esc(
              [m.amount, m.frequency].filter(Boolean).join(', '),
            )}${m.startedOn ? ` · since ${esc(day(m.startedOn))}` : ''}${
              typeof m.quantity === 'number' ? ` · ${m.quantity} left` : ''
            }</p>${dates}`
          })
          .join(''),
      ),
    )
  }

  if (pet.socialStamps?.length) {
    const labels = pet.socialStamps.map(
      (id) => SOCIAL_STAMPS.find((s) => s.id === id)?.label ?? id,
    )
    parts.push(section('Socialisation passport', list(labels.map(esc))))
  }

  if (pet.lumps?.length) {
    parts.push(
      section(
        'Lump diary',
        pet.lumps
          .map((l) => {
            const photos = l.photos
              .map((p) => {
                const url = safeUrl(p.url)
                const caption = `${esc(day(p.takenAt))}${p.sizeReference ? ` · next to ${esc(p.sizeReference)}` : ''}`
                return url
                  ? `<figure><img src="${esc(url)}" alt="${esc(l.location)}, ${esc(day(p.takenAt))}" loading="lazy"><figcaption>${caption}</figcaption></figure>`
                  : `<p class="note">Photo, ${caption}</p>`
              })
              .join('')
            return `<h3>${esc(l.location)}</h3><p>First noticed ${esc(day(l.firstSeen))}</p>${
              l.note ? `<p>${esc(l.note)}</p>` : ''
            }${photos}`
          })
          .join(''),
      ),
    )
  }

  const notes = Object.entries(pet.careNotes ?? {}).filter(([, v]) => v && String(v).trim())
  if (notes.length) {
    parts.push(
      section(
        'Notes for a sitter',
        `<table>${notes
          .map(
            ([k, v]) =>
              `<tr><th scope="row">${esc(CARE_NOTE_LABELS[k as keyof typeof CARE_NOTE_LABELS] ?? k)}</th><td>${esc(String(v))}</td></tr>`,
          )
          .join('')}</table>`,
      ),
    )
  }

  const photo = safeUrl(pet.photo?.avatarUrl)
  if (photo) {
    parts.push(
      section('Photo', `<img class="portrait" src="${esc(photo)}" alt="${name}">`),
    )
  }

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${name} — Clovara record</title>
<style>
  body { font: 16px/1.55 system-ui, -apple-system, 'Segoe UI', sans-serif; color: #1f2a24; background: #fbf8f2; margin: 0; padding: 32px 20px 48px; }
  main { max-width: 680px; margin: 0 auto; }
  h1 { font-family: Georgia, 'Times New Roman', serif; font-weight: 600; font-size: 30px; line-height: 1.2; margin: 0 0 6px; }
  h2 { font-family: Georgia, 'Times New Roman', serif; font-weight: 600; font-size: 21px; margin: 32px 0 10px; padding-top: 16px; border-top: 1px solid #e3ddd0; }
  h3 { font-size: 16px; margin: 18px 0 4px; }
  p { margin: 6px 0; }
  .lede, .note, figcaption { color: #5b6660; }
  .note, figcaption { font-size: 14px; }
  table { border-collapse: collapse; width: 100%; }
  th, td { text-align: left; vertical-align: top; padding: 7px 0; border-bottom: 1px solid #efe9dd; }
  th { font-weight: 500; width: 42%; padding-right: 16px; color: #5b6660; }
  ul { padding-left: 20px; margin: 6px 0; }
  figure { margin: 12px 0; }
  img { max-width: 100%; height: auto; border-radius: 10px; }
  .portrait { max-width: 240px; }
  footer { margin-top: 36px; padding-top: 16px; border-top: 1px solid #e3ddd0; font-size: 14px; color: #5b6660; }
</style>
</head>
<body>
<main>
<h1>Everything on record for ${name}</h1>
<p class="lede">Made on ${esc(day(now.toISOString()))}, on your own device. Nothing was sent anywhere to make it.</p>
${parts.join('\n')}
<footer>
<p>${name}&rsquo;s plan — the healthy-years range, the life stages, what to watch for — is worked out from this record each time it is shown, so it is not stored separately${
    pet.lastReviewedRange ? ', apart from the range at the last yearly check, above' : ''
  }.</p>
<p>The same record, as data another program can read, is the other download in the Health File: &ldquo;As data (.json)&rdquo;.</p>
</footer>
</main>
</body>
</html>
`
}

export function recordExport(pet: PetProfile, now: Date): RecordFiles {
  const record = {
    format: RECORD_FORMAT,
    version: RECORD_VERSION,
    exportedAt: now.toISOString(),
    // As held — every field, including ones this build does not display.
    pet: JSON.parse(JSON.stringify(pet)) as PetProfile,
  }
  return {
    baseName: `${slug(pet.name)}-clovara-record`,
    html: renderHtml(pet, now),
    json: JSON.stringify(record, null, 2) + '\n',
  }
}
