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
  /** Emails a one-time sign-in link. Creates the account if there isn't one. */
  sendSignInLink: (email: string) => Promise<void>
  /** Completes a link. `href` is the full URL the link landed on. */
  completeSignInLink: (email: string, href: string) => Promise<UserCredential>
  /** The SDK's own authoritative check, after `looksLikeSignInLink` got us here. */
  isSignInLink: (href: string) => boolean
  signInWithGoogle: () => Promise<UserCredential>
  signOut: () => Promise<void>
  watch: (cb: (user: User | null) => void) => () => void
}

/**
 * Where a sign-in link comes back to.
 *
 * Origin + path, with query and hash dropped: the link must land on the app,
 * not on whatever deep link the person happened to be looking at when they
 * asked for it, and Firebase appends its own query parameters. The domain has
 * to be on the project's authorised-domain list or Firebase refuses to send.
 */
function linkReturnUrl(): string {
  return `${window.location.origin}${window.location.pathname}`
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
      sendSignInLinkToEmail,
      signInWithEmailLink,
      isSignInWithEmailLink,
      signInWithPopup,
      GoogleAuthProvider,
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
      sendSignInLink: (email) =>
        sendSignInLinkToEmail(auth, email.trim(), {
          url: linkReturnUrl(),
          // Required: it is what makes the link open in the app rather than
          // bouncing through a Firebase-hosted page.
          handleCodeInApp: true,
        }),
      completeSignInLink: (email, href) => signInWithEmailLink(auth, email.trim(), href),
      isSignInLink: (href) => isSignInWithEmailLink(auth, href),
      signInWithGoogle: () => {
        const provider = new GoogleAuthProvider()
        // Always show the chooser. Silently reusing a signed-in Google account
        // is a nasty surprise on a shared or demo laptop.
        provider.setCustomParameters({ prompt: 'select_account' })
        return signInWithPopup(auth, provider)
      },
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
