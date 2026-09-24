/**
 * C0 — the one-page summary for a vet visit (SPEC-COMPANION §6, §9).
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * WHAT THIS IS: everything an owner would be asked in the room and would not
 * remember. Conditions on file, what has been vaccinated and when, the weight
 * and body-condition picture, the daily routine, and what changed this year.
 *
 * WHAT IT IS NOT, AND THE THREE THINGS IT DELIBERATELY LEAVES OUT:
 *
 *  1. THE PROJECTION. The healthy-years range is a planning number built from
 *     breed medians. In front of a clinician, beside real clinical facts, it
 *     would read as a prognosis for this animal — which it is not, and which we
 *     are in no position to give. It is absent, and §3 says so on the page.
 *
 *  2. ANY INTERPRETATION. It reports; it does not conclude. No "consistent
 *     with", no severity, no suggestion of what to look at first. Invariant 4
 *     binds hardest in the one room where somebody qualified is present.
 *
 *  3. ANYTHING WE WERE NOT TOLD. A field nobody answered is printed as not
 *     asked, never as normal or as absent. A vet reading "no conditions" would
 *     reasonably take it as a negative history; "not asked" is the truth.
 *
 * PROVENANCE IS ON EVERY LINE (invariant 8). A vet must be able to tell what
 * the owner said from what came off a document, because they carry different
 * weight and only one of them has been read by anybody.
 * ═══════════════════════════════════════════════════════════════════════════
 *
 * Pure; clock injected.
 */
import { KNOWN_CONDITIONS } from '../data/conditions'
import { CORE_VACCINES, VACCINE_DOSES } from '../data/vaccines'
import { BCS_LABELS } from '../components/Silhouette'
import type { PetProfile, Projection } from '../data/types'
import { longDate } from '../share/cardLayout'

/** How a line was come by, in words a clinician can weigh. */
export type Told = 'owner said' | 'from a document' | 'not asked'

export interface SummaryLine {
  label: string
  value: string
  told: Told
}

export interface SummarySection {
  heading: string
  lines: SummaryLine[]
  /** Shown when the section has nothing, instead of hiding it. */
  emptyNote?: string
}

export interface VisitSummary {
  petName: string
  headline: string
  sections: SummarySection[]
  /** Printed at the foot. Not decoration — it is what makes the rest usable. */
  caveats: string[]
  generatedAt: string
}

const ACTIVITY: Record<string, string> = {
  low: 'not very active',
  moderate: 'active most days',
  high: 'very active',
}
const DENTAL: Record<string, string> = {
  daily: 'teeth cleaned daily',
  weekly: 'teeth cleaned weekly',
  rarely: 'teeth cleaned rarely',
}
const DIET: Record<string, string> = {
  measured: 'measured meals',
  'free-fed': 'food available all day',
  unsure: 'not sure',
}
const OUTDOOR: Record<string, string> = {
  indoor: 'indoors only',
  'indoor-outdoor': 'in and out',
  outdoor: 'mostly outdoors',
}

const line = (label: string, value: string | undefined, told: Told): SummaryLine =>
  value === undefined || value === ''
    ? { label, value: 'Not asked', told: 'not asked' }
    : { label, value, told }

export function buildVisitSummary(pet: PetProfile, projection: Projection, now: Date): VisitSummary {
  const age = projection.ageYears
  const ageText =
    age < 1 ? `${Math.max(1, Math.round(age * 12))} months old` : `${Math.floor(age)} years old`

  // ── Who ────────────────────────────────────────────────────────────────
  const who: SummaryLine[] = [
    { label: 'Breed', value: projection.breed.name, told: 'owner said' },
    {
      label: 'Age',
      value: pet.birthDateApprox
        ? `${ageText} (birthday estimated, not known)`
        : `${ageText} (born ${longDate(pet.birthDate)})`,
      told: 'owner said',
    },
    { label: 'Sex', value: pet.sex === 'female' ? 'Female' : 'Male', told: 'owner said' },
    line(
      'Neutered',
      pet.neutered === undefined ? undefined : pet.neutered ? 'Yes' : 'No',
      'owner said',
    ),
  ]
  if (pet.neutered === true && pet.neuterAgeBand) {
    who.push({ label: 'Age when neutered', value: pet.neuterAgeBand, told: 'owner said' })
  }

  // ── Conditions ─────────────────────────────────────────────────────────
  const named = (pet.conditionIds ?? []).map(
    (id) => KNOWN_CONDITIONS.find((k) => k.id === id)?.name ?? id,
  )
  const conditions: SummarySection = {
    heading: 'Already on file',
    lines: named.map((n) => ({ label: n, value: 'Declared', told: 'owner said' as Told })),
    emptyNote: pet.conditionsReviewed
      ? 'The owner was shown the list and reported nothing diagnosed. Not a clinical negative history.'
      : 'Nobody has been asked. This is not a negative history — the question has not been put.',
  }

  // ── Body ───────────────────────────────────────────────────────────────
  const body: SummaryLine[] = [
    line(
      'Body condition',
      pet.bodyConditionScore !== undefined
        ? `${BCS_LABELS[pet.bodyConditionScore].label} — ${BCS_LABELS[pet.bodyConditionScore].detail.toLowerCase()}. Owner picked this from five silhouettes; not a clinical BCS.`
        : undefined,
      'owner said',
    ),
    line('Weight', pet.weightLb > 0 ? `${pet.weightLb} lb` : undefined, 'owner said'),
  ]

  // ── Routine ────────────────────────────────────────────────────────────
  const routine: SummaryLine[] = [
    line('Activity', pet.activity ? ACTIVITY[pet.activity] : undefined, 'owner said'),
    line('Teeth', pet.dental ? DENTAL[pet.dental] : undefined, 'owner said'),
    line('Feeding', pet.diet ? DIET[pet.diet] : undefined, 'owner said'),
  ]
  if (pet.species === 'cat') {
    routine.push(
      line('Outdoor access', pet.outdoorAccess ? OUTDOOR[pet.outdoorAccess] : undefined, 'owner said'),
    )
  }
  if (pet.careNotes?.meds) {
    routine.push({ label: 'Medication', value: pet.careNotes.meds, told: 'owner said' })
  }

  // ── Vaccinations ───────────────────────────────────────────────────────
  const shots = (pet.vaccineRecords ?? [])
    .map((r) => {
      const dose = VACCINE_DOSES.find((d) => d.id === r.doseId)
      const vac = CORE_VACCINES.find((v) => v.id === dose?.vaccineId)
      return dose && vac
        ? { label: `${vac.label} — ${dose.label.toLowerCase()}`, value: longDate(r.givenOn), given: r.givenOn }
        : null
    })
    .filter((x): x is NonNullable<typeof x> => x !== null)
    .sort((a, b) => a.given.localeCompare(b.given))

  const vaccinations: SummarySection = {
    heading: 'Vaccinations the owner has recorded',
    lines: shots.map((s) => ({ label: s.label, value: s.value, told: 'owner said' as Told })),
    emptyNote:
      'Nothing recorded here. That means nobody typed it in — not that nothing was given.',
  }

  return {
    petName: pet.name,
    headline: `${pet.name} — ${projection.breed.name}, ${ageText}`,
    sections: [
      { heading: 'Who they are', lines: who },
      conditions,
      { heading: 'Shape', lines: body },
      { heading: 'Day to day', lines: routine },
      vaccinations,
    ],
    caveats: [
      'Everything here was reported by the owner through an app. None of it has been examined or verified by a veterinarian.',
      'Blank fields mean the question was not asked, not that the answer is no.',
      'This is not a medical record and does not replace one.',
      // The one that matters most, and the reason the projection is absent.
      "Clovara's healthy-years projection is deliberately not included. It is built from breed averages for planning, and it is not a prognosis for this animal.",
    ],
    generatedAt: now.toISOString(),
  }
}

/**
 * The same thing as plain text, for pasting into a practice system.
 *
 * Deliberately the primary output. A vet's computer does not accept a
 * screenshot, and an owner reading aloud from a phone is what this exists to
 * replace.
 */
export function summaryAsText(s: VisitSummary): string {
  const out: string[] = [s.headline, `Prepared ${longDate(s.generatedAt)} · Clovara`, '']
  for (const section of s.sections) {
    out.push(section.heading.toUpperCase())
    if (section.lines.length === 0) {
      if (section.emptyNote) out.push(`  ${section.emptyNote}`)
    } else {
      for (const l of section.lines) {
        out.push(`  ${l.label}: ${l.value}${l.told === 'not asked' ? '' : ` (${l.told})`}`)
      }
    }
    out.push('')
  }
  out.push('NOTES')
  for (const c of s.caveats) out.push(`  - ${c}`)
  return out.join('\n')
}
