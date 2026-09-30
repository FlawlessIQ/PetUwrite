/**
 * Moment-email opt-in (Phase B, AO6), through the Life functions — the choice
 * lives server-side in `life_prefs/{uid}`, which no client rule can reach.
 *
 * EMAIL_MOMENTS_ENABLED is a build flag and is OFF in production: the switch
 * must not appear until the functions it calls are deployed and a sending
 * domain exists. Set VITE_EMAIL_MOMENTS=1 to build it in (emulator, preview).
 */
import { FIREBASE_CONFIG } from '../auth/config'

export const EMAIL_MOMENTS_ENABLED = import.meta.env.VITE_EMAIL_MOMENTS === '1'

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
  return (await fns.httpsCallable<unknown, T>(functions, name)(data)).data
}

export const getEmailPrefs = () => callable<{ moments: boolean }>('getEmailPrefs', {})
export const setEmailPrefs = (moments: boolean) => callable<{ moments: boolean }>('setEmailPrefs', { moments })
