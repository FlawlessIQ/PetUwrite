import { FIREBASE_CONFIG } from '../auth/config'

/**
 * Calls a Life Cloud Function (BACKLOG UB11 — one copy instead of four).
 *
 * The Firebase SDK is imported here, on call, never at module load: every
 * caller is behind a signed-in action, and the demo contract is that a
 * signed-out visitor loads no Firebase at all.
 */
export async function callable<T>(name: string, data: unknown = {}): Promise<T> {
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
  return (await fns.httpsCallable<unknown, T>(functions, name)(data)).data
}
