import { FIREBASE_CONFIG } from '../auth/config'

/**
 * The family circle (SPEC §4.3), client side.
 *
 * Both calls are Cloud Functions, not Firestore writes: a client that could add
 * a uid to a household document could add itself to any household it could name.
 * The rules deny clients all access to `life_invites` for the same reason.
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

export interface InviteResult {
  code: string
  expiresInDays: number
}

export function createInvite(): Promise<InviteResult> {
  return callable<InviteResult>('createHouseholdInvite', {})
}

export function redeemInvite(code: string): Promise<{ householdId: string }> {
  return callable<{ householdId: string }>('redeemHouseholdInvite', { code })
}

/**
 * Turns a callable rejection into something worth reading.
 *
 * The functions throw HttpsError with messages written for people — "That
 * invite has already been used", not a code — so the message is preserved where
 * there is one, and only the unhandled case gets a generic sentence.
 */
export function inviteError(err: unknown): string {
  const e = err as { code?: string; message?: string }
  if (e?.message && !/internal|unknown/i.test(e.message)) {
    return e.message.replace(/^[a-z-]+\/[a-z-]+:?\s*/i, '')
  }
  return 'Something went wrong. Try again in a moment.'
}
