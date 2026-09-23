/**
 * The only module in the app that touches the Firebase SDK.
 *
 * Every import of `firebase/*` in here is dynamic, so Vite splits the SDK into
 * its own chunk and nothing in the signed-out demo path pulls it in. Loading is
 * triggered by exactly two things: a real auth interaction, or a session hint
 * left behind by a previous sign-in (see `session.ts`).
 *
 * `loadAuth()` is idempotent and concurrency-safe — two components calling it
 * at once share one promise and one Firebase app instance.
 */
import { FIREBASE_CONFIG } from './config'
import type { Auth, User, UserCredential } from 'firebase/auth'

/** Set VITE_USE_EMULATORS=1 to point a dev build at the local emulator suite. */
const USE_EMULATORS = import.meta.env.VITE_USE_EMULATORS === '1'

export type { User }

interface AuthKit {
  auth: Auth
  signInWithEmail: (email: string, password: string) => Promise<UserCredential>
  createAccount: (email: string, password: string) => Promise<UserCredential>
  signInWithGoogle: () => Promise<UserCredential>
  sendReset: (email: string) => Promise<void>
  signOut: () => Promise<void>
  watch: (cb: (user: User | null) => void) => () => void
}

let kit: Promise<AuthKit> | null = null

export function loadAuth(): Promise<AuthKit> {
  if (kit) return kit
  kit = (async () => {
    const [{ initializeApp, getApps, getApp }, authMod] = await Promise.all([
      import('firebase/app'),
      import('firebase/auth'),
    ])
    const {
      getAuth,
      connectAuthEmulator,
      browserLocalPersistence,
      setPersistence,
      signInWithEmailAndPassword,
      createUserWithEmailAndPassword,
      signInWithPopup,
      GoogleAuthProvider,
      sendPasswordResetEmail,
      signOut: fbSignOut,
      onAuthStateChanged,
    } = authMod

    // getApps() guard: a hot reload in dev would otherwise re-initialise and throw.
    const app = getApps().length ? getApp() : initializeApp(FIREBASE_CONFIG)
    const auth = getAuth(app)
    if (USE_EMULATORS) {
      try {
        connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true })
      } catch {
        /* already connected on a hot reload */
      }
    }

    // Survive a reload and a closed tab. This is what the session hint promises.
    await setPersistence(auth, browserLocalPersistence).catch(() => {
      /* Safari in private mode refuses local persistence. Sign-in still works
         for the life of the tab, which is better than failing outright. */
    })

    return {
      auth,
      signInWithEmail: (email, password) =>
        signInWithEmailAndPassword(auth, email.trim(), password),
      createAccount: (email, password) =>
        createUserWithEmailAndPassword(auth, email.trim(), password),
      signInWithGoogle: () => {
        const provider = new GoogleAuthProvider()
        // Always show the chooser. Silently reusing a signed-in Google account
        // is a nasty surprise on a shared or demo laptop.
        provider.setCustomParameters({ prompt: 'select_account' })
        return signInWithPopup(auth, provider)
      },
      sendReset: (email) => sendPasswordResetEmail(auth, email.trim()),
      signOut: () => fbSignOut(auth),
      watch: (cb) => onAuthStateChanged(auth, cb),
    }
  })()
  // A failed load must not poison every later attempt — let the next call retry.
  kit.catch(() => {
    kit = null
  })
  return kit
}

/** True once the SDK has actually been pulled in. Used by tests and diagnostics. */
export function authLoaded(): boolean {
  return kit !== null
}
