import { FIREBASE_CONFIG } from '../auth/config'

/**
 * Sitter Mode (SPEC §6.6), client side.
 *
 * Creation, listing and revocation are callables — `life_sitter_links` is
 * deny-all in the rules, because a client able to read it could enumerate every
 * live sitter link on the project.
 *
 * READING A CARD IS A PLAIN FETCH, ON PURPOSE. The person opening a sitter link
 * is a neighbour with a URL, not a signed-in user, and making them download the
 * Firebase SDK to read a fridge note would be slow and pointless. It is the one
 * unauthenticated read path in the product and it goes through an endpoint that
 * returns the same 404 for expired, revoked and never-existed.
 */
async function callable<T>(name: string, data: unknown): Promise<T> {
  const [{ getApps, getApp, initializeApp }, fns] = await Promise.all([
    import('firebase/app'),
    import('firebase/functions'),
  ])
  const app = getApps().length ? getApp() : initializeApp(FIREBASE_CONFIG)
  const functions = fns.getFunctions(app, 'us-central1')
  if (import.meta.env.VITE_USE_EMULATORS === '1') {
    try {
      fns.connectFunctionsEmulator(functions, '127.0.0.1', 5001)
    } catch {
      /* already connected */
    }
  }
  const fn = fns.httpsCallable<unknown, T>(functions, name)
  return (await fn(data)).data
}

export interface SitterLink {
  token: string
  petId: string
  expiresAt: string
  createdAt?: string
}

export interface SitterCard {
  name: string
  species: string | null
  breedId: string | null
  photoUrl: string | null
  feeding: string | null
  medication: string | null
  quirks: string | null
  vetName: string | null
  vetPhone: string | null
  emergencyName: string | null
  emergencyPhone: string | null
}

export function createSitterLink(petId: string, days = 7): Promise<{ token: string; expiresInDays: number }> {
  return callable('createSitterLink', { petId, days })
}

export function revokeSitterLink(token: string): Promise<{ revoked: boolean }> {
  return callable('revokeSitterLink', { token })
}

export async function listSitterLinks(): Promise<SitterLink[]> {
  const r = await callable<{ links: SitterLink[] }>('listSitterLinks', {})
  return r.links ?? []
}

/** Where the public endpoint lives. */
function sitterCardUrl(token: string): string {
  if (import.meta.env.VITE_USE_EMULATORS === '1') {
    return `http://127.0.0.1:5001/${FIREBASE_CONFIG.projectId}/us-central1/sitterCard?t=${encodeURIComponent(token)}`
  }
  return `https://us-central1-${FIREBASE_CONFIG.projectId}.cloudfunctions.net/sitterCard?t=${encodeURIComponent(token)}`
}

/** The public read. Null for expired, revoked and never-existed alike. */
export async function readSitterCard(
  token: string,
): Promise<{ card: SitterCard; expiresAt: string } | null> {
  try {
    const res = await fetch(sitterCardUrl(token), { cache: 'no-store' })
    if (!res.ok) return null
    return (await res.json()) as { card: SitterCard; expiresAt: string }
  } catch {
    return null
  }
}

/** The link somebody actually sends. */
export function sitterShareUrl(token: string): string {
  return `${window.location.origin}/#/sitter/${encodeURIComponent(token)}`
}
