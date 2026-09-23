/**
 * Vaccine Autopilot (SPEC §6.4): the core schedule, and a place to record what
 * actually happened.
 *
 * READ THIS BEFORE CHANGING ANYTHING HERE.
 *
 * This is the most clinically adjacent surface in the product, and it is
 * deliberately built as a RECORD with a reminder attached, not as a
 * prescription. Invariant 4 — the companion never diagnoses — extends to this:
 * a vaccination schedule is a veterinary decision that depends on the brand
 * used, the local disease picture, the law where somebody lives, and the animal
 * in front of the vet. We do not set it. We say what a typical core schedule
 * looks like, we remember what an owner tells us happened, and we say whose
 * decision it is every time.
 *
 * SCOPE IS CORE ONLY. Non-core vaccines — leptospirosis, kennel cough, Lyme,
 * feline leukaemia for an outdoor cat — are genuinely lifestyle-and-region
 * dependent, and a checklist that listed them would be making a recommendation
 * for an animal we have never seen. They are named as a question to ask,
 * nowhere near a schedule.
 *
 * RABIES IS LAW, NOT MEDICINE, AND THE LAW DIFFERS. It is mandated for most
 * pets in the United States, not routinely given in the UK or Ireland outside
 * travel. It carries `lawDependent` so the surface can say so rather than
 * either omitting it or presenting it as universal.
 *
 * Shape and emphasis follow published WSAVA core-vaccine guidance. Windows are
 * given as ranges because that is how the guidance gives them.
 */
import type { Species } from './types'

export interface VaccineDose {
  id: string
  /** Which course this belongs to. */
  vaccineId: string
  label: string
  /** Typical age window in weeks. */
  fromWeeks: number
  toWeeks: number
}

export interface CoreVaccine {
  id: string
  /** What a vet is likely to write on the card. */
  label: string
  /** What it protects against, in plain words. */
  protects: string
  species: Species
  /** True where whether it is given at all is a matter of local law. */
  lawDependent?: boolean
}

export const CORE_VACCINES: CoreVaccine[] = [
  {
    id: 'dog-dhp',
    label: 'DHP / DAPP',
    protects: 'Distemper, hepatitis and parvovirus — the three that kill puppies.',
    species: 'dog',
  },
  {
    id: 'dog-rabies',
    label: 'Rabies',
    protects: 'Rabies. Whether and when it is given is set by law where you live, not by us.',
    species: 'dog',
    lawDependent: true,
  },
  {
    id: 'cat-fvrcp',
    label: 'FVRCP',
    protects: 'Panleukopenia, herpesvirus and calicivirus — the core three for cats.',
    species: 'cat',
  },
  {
    id: 'cat-rabies',
    label: 'Rabies',
    protects: 'Rabies. Whether and when it is given is set by law where you live, not by us.',
    species: 'cat',
    lawDependent: true,
  },
]

/**
 * The primary course and the first booster.
 *
 * Deliberately stops there. Adult boosters run on a multi-year interval that
 * depends on the product used and on local guidance, so beyond the first
 * booster the surface says "your vet will tell you when" rather than inventing
 * a date it cannot know.
 */
export const VACCINE_DOSES: VaccineDose[] = [
  // ── Dog primary course ───────────────────────────────────────────────────
  { id: 'dog-dhp-1', vaccineId: 'dog-dhp', label: 'First dose', fromWeeks: 6, toWeeks: 9 },
  { id: 'dog-dhp-2', vaccineId: 'dog-dhp', label: 'Second dose', fromWeeks: 10, toWeeks: 13 },
  { id: 'dog-dhp-3', vaccineId: 'dog-dhp', label: 'Third dose', fromWeeks: 14, toWeeks: 17 },
  {
    id: 'dog-dhp-booster',
    vaccineId: 'dog-dhp',
    label: 'First adult booster',
    fromWeeks: 26,
    toWeeks: 78,
  },
  { id: 'dog-rabies-1', vaccineId: 'dog-rabies', label: 'First dose', fromWeeks: 12, toWeeks: 20 },
  {
    id: 'dog-rabies-2',
    vaccineId: 'dog-rabies',
    label: 'Booster',
    fromWeeks: 52,
    toWeeks: 78,
  },

  // ── Cat primary course ───────────────────────────────────────────────────
  { id: 'cat-fvrcp-1', vaccineId: 'cat-fvrcp', label: 'First dose', fromWeeks: 6, toWeeks: 9 },
  { id: 'cat-fvrcp-2', vaccineId: 'cat-fvrcp', label: 'Second dose', fromWeeks: 10, toWeeks: 13 },
  { id: 'cat-fvrcp-3', vaccineId: 'cat-fvrcp', label: 'Third dose', fromWeeks: 14, toWeeks: 21 },
  {
    id: 'cat-fvrcp-booster',
    vaccineId: 'cat-fvrcp',
    label: 'First adult booster',
    fromWeeks: 26,
    toWeeks: 78,
  },
  { id: 'cat-rabies-1', vaccineId: 'cat-rabies', label: 'First dose', fromWeeks: 12, toWeeks: 20 },
  { id: 'cat-rabies-2', vaccineId: 'cat-rabies', label: 'Booster', fromWeeks: 52, toWeeks: 78 },
]

/** Named as questions for a vet, never scheduled. */
export const NON_CORE_TO_ASK: Record<Species, string[]> = {
  dog: [
    'Leptospirosis — depends on where you walk and what the local picture is.',
    'Kennel cough — usually asked for by boarding kennels and some day care.',
    'Lyme — only in some regions, and only for some dogs.',
  ],
  cat: [
    'Feline leukaemia — the usual question for any cat who goes outside.',
    'Chlamydia and bordetella — occasionally, in multi-cat households.',
  ],
}

export const VACCINE_DISCLAIMER =
  'Your vet sets the schedule, not us. Brands differ, local disease pressure differs, and the law differs — what is below is what a typical core course looks like so you know roughly what to expect and what to ask.'

export const VACCINE_RECORD_NOTE =
  'Recording a date here is your note to yourself. It is not a medical record and it does not reach your vet.'
