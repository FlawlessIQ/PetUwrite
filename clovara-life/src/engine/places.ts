/**
 * The real emergency-vet lookup (SPEC §6.5), behind the `PlacesProvider` seam.
 *
 * WHY THIS RUNS IN THE BROWSER AND NOT IN A FUNCTION. Finding the nearest open
 * emergency vet needs somebody's location. Routing it through our server would
 * put a frightened owner's coordinates in our logs for no benefit — the
 * request has to reach Google either way, and one fewer party holding it is
 * strictly better. The key is therefore a browser key, restricted to one API
 * and one referrer, and rate-capped at the project.
 *
 * WHAT IT ASKS FOR IS DELIBERATELY NARROW. Open now, veterinary care, nearest
 * first, a handful of results. No reviews, no photos, no place details beyond
 * name, address and phone — each extra field is a billing SKU and none of them
 * help somebody at 2am.
 */
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
  'We cannot look up your nearest open emergency vet yet. Search for "emergency vet near me", or ring a poison line — they will tell you where to go.'


const SEARCH_TEXT = 'https://places.googleapis.com/v1/places:searchText'

/**
 * WHY A TEXT SEARCH AND NOT A NEARBY-BY-TYPE SEARCH.
 *
 * The obvious implementation asks for `includedTypes: ['veterinary_care']`
 * nearest-first. Tried against central London at 2am it returned a cattery, a
 * telemedicine office and two closed daytime practices — because
 * `veterinary_care` covers groomers, boarding and anything vet-adjacent, and
 * `openNow` is a field you read rather than a filter you apply.
 *
 * "emergency vet" with `openNow: true` returns 24-hour animal hospitals that
 * are open, with phone numbers. That is the whole question this screen exists
 * to answer.
 */

/** Only what is needed. Every extra field here is money and noise. */
const FIELD_MASK = [
  'places.displayName',
  'places.formattedAddress',
  'places.nationalPhoneNumber',
  'places.currentOpeningHours.openNow',
  'places.location',
].join(',')

function distanceKm(
  a: { lat: number; lng: number },
  b: { latitude: number; longitude: number },
): number {
  const R = 6371
  const dLat = ((b.latitude - a.lat) * Math.PI) / 180
  const dLng = ((b.longitude - a.lng) * Math.PI) / 180
  const lat1 = (a.lat * Math.PI) / 180
  const lat2 = (b.latitude * Math.PI) / 180
  const h =
    Math.sin(dLat / 2) ** 2 + Math.sin(dLng / 2) ** 2 * Math.cos(lat1) * Math.cos(lat2)
  return Math.round(2 * R * Math.asin(Math.sqrt(h)) * 10) / 10
}

export function makeGooglePlacesProvider(apiKey: string): PlacesProvider {
  return {
    id: 'google-places',
    available: !!apiKey,

    async findEmergencyVets(near) {
      if (!apiKey) return []

      const search = async (openNow: boolean) => {
        const res = await fetch(SEARCH_TEXT, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            // A header, never a query string: a key in a URL ends up in logs,
            // referrers and browser history.
            'X-Goog-Api-Key': apiKey,
            'X-Goog-FieldMask': FIELD_MASK,
          },
          body: JSON.stringify({
            textQuery: 'emergency vet',
            openNow,
            maxResultCount: 5,
            rankPreference: 'DISTANCE',
            locationBias: {
              circle: { center: { latitude: near.lat, longitude: near.lng }, radius: 40000 },
            },
          }),
        })
        if (!res.ok) throw new Error(`places ${res.status}`)
        return res.json()
      }

      // Open ones first. If nothing is open, show the nearest anyway rather
      // than an empty list — at 2am "no results" reads as "there is nowhere",
      // and a closed practice's number is still a number worth having.
      let body = (await search(true)) as { places?: unknown[] }
      if (!body.places?.length) body = (await search(false)) as { places?: unknown[] }

      const parsed = body as {
        places?: {
          displayName?: { text?: string }
          formattedAddress?: string
          nationalPhoneNumber?: string
          currentOpeningHours?: { openNow?: boolean }
          location?: { latitude: number; longitude: number }
        }[]
      }
      return (parsed.places ?? []).map<EmergencyVet>((p) => ({
        name: p.displayName?.text ?? 'Veterinary practice',
        address: p.formattedAddress ?? '',
        tel: p.nationalPhoneNumber,
        openNow: p.currentOpeningHours?.openNow,
        distanceKm: p.location ? distanceKm(near, p.location) : undefined,
      }))
    },
  }
}

/**
 * Sorted the way somebody in trouble needs them: open first, then nearest.
 *
 * A closed practice two streets away is worse than an open one twenty minutes
 * out, and Google's own ranking does not know that — `openNow` is a field, not
 * a sort. Practices whose hours are unknown sort BELOW confirmed-open ones and
 * above confirmed-closed, because "we do not know" is not "yes".
 */
export function forEmergency(vets: EmergencyVet[]): EmergencyVet[] {
  const rank = (v: EmergencyVet) => (v.openNow === true ? 0 : v.openNow === undefined ? 1 : 2)
  return [...vets].sort(
    (a, b) => rank(a) - rank(b) || (a.distanceKm ?? 1e9) - (b.distanceKm ?? 1e9),
  )
}

/** Built from the environment, so a missing key degrades rather than throws. */
export function placesFromEnv(): PlacesProvider | null {
  const key = import.meta.env.VITE_GOOGLE_PLACES_KEY as string | undefined
  return key ? makeGooglePlacesProvider(key) : null
}
