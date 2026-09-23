/**
 * Toxin risk banding (SPEC §6.5).
 *
 * Pure. Takes a weight and an amount, returns a band and never a number.
 *
 * BIASED TOWARDS THE PHONE CALL EVERYWHERE. Unknown weight, unknown amount,
 * unknown form, a species we have no data for — every one of those resolves
 * UPWARDS, not downwards. The cost of a false 'call-now' is somebody's evening.
 * The cost of a false 'monitor' is an animal.
 */
import { TOXINS, type RiskBand, type Toxin } from '../data/toxins'
import type { PetProfile, Species } from '../data/types'

const LB_PER_KG = 2.20462

export interface BandResult {
  band: RiskBand
  /** True when we could not compute and escalated on principle. */
  escalatedForUncertainty: boolean
  /** Plain-words reason, for the surface to show. */
  because: string
}

/** Everything this species could have eaten, in a stable order. */
export function toxinsFor(species: Species): Toxin[] {
  return TOXINS.filter((t) => t.species.includes(species))
}

/** Free-text search over names and the words people actually type. */
export function findToxins(query: string, species: Species): Toxin[] {
  const q = query.trim().toLowerCase()
  if (!q) return toxinsFor(species)
  return toxinsFor(species).filter(
    (t) =>
      t.name.toLowerCase().includes(q) ||
      t.aka.some((a) => a.includes(q) || q.includes(a)),
  )
}

export function bandFor(
  toxin: Toxin,
  pet: PetProfile,
  input: { formId?: string; grams?: number },
): BandResult {
  // No safe dose. Weight and amount are not consulted, deliberately.
  if (toxin.alwaysCall) {
    return {
      band: 'call-now',
      escalatedForUncertainty: false,
      because: 'There is no amount of this treated as safe.',
    }
  }

  const form = toxin.forms?.find((f) => f.id === input.formId)
  const weightKg = pet.weightLb > 0 ? pet.weightLb / LB_PER_KG : 0

  if (!form || !input.grams || input.grams <= 0 || weightKg <= 0 || !toxin.thresholds) {
    return {
      band: 'call-now',
      escalatedForUncertainty: true,
      because:
        weightKg <= 0
          ? 'We do not know what they weigh, so we cannot work out whether this is a little or a lot. Ring.'
          : 'Without knowing what kind and roughly how much, we cannot tell a mouthful from a packet. Ring.',
    }
  }

  const mgPerKg = (form.mgPerGram * input.grams) / weightKg
  if (mgPerKg >= toxin.thresholds.callNow) {
    return {
      band: 'call-now',
      escalatedForUncertainty: false,
      because: `That is a lot for a ${pet.name.length ? pet.name : 'pet'} of their size.`,
    }
  }
  if (mgPerKg >= toxin.thresholds.vetToday) {
    return {
      band: 'vet-today',
      escalatedForUncertainty: false,
      because: 'Enough to be worth being seen about today.',
    }
  }
  return {
    band: 'monitor',
    escalatedForUncertainty: false,
    because:
      'A small amount for their size. Watch them, and ring if anything at all changes — this is a guide, not a clearance.',
  }
}

export const BAND_LABEL: Record<RiskBand, string> = {
  'call-now': 'Ring now',
  'vet-today': 'Be seen today',
  monitor: 'Watch closely',
}

/**
 * Nearest open emergency vet.
 *
 * SPEC §6.5 wants a Places lookup. That needs a Google Places key and billing,
 * which is Conor's to obtain, so the seam exists and the null implementation is
 * honest about it rather than pretending to search. It must never look like it
 * tried and found nothing — at 2am that reads as "there is nowhere open".
 */
export interface EmergencyVet {
  name: string
  address: string
  tel?: string
  openNow?: boolean
  distanceKm?: number
}

export interface PlacesProvider {
  id: string
  available: boolean
  findEmergencyVets(near: { lat: number; lng: number }): Promise<EmergencyVet[]>
}

export const NULL_PLACES_PROVIDER: PlacesProvider = {
  id: 'none',
  available: false,
  async findEmergencyVets() {
    return []
  },
}

export const NO_PLACES_COPY =
  'We cannot look up your nearest open emergency vet yet. Search for "emergency vet near me", or ring a poison line below — they will tell you where to go.'
