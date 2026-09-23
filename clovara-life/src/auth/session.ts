/**
 * The pure parts of auth: everything here is testable without a browser, a
 * network, or the Firebase SDK. Anything that needs those lives in
 * `firebase.ts` behind a dynamic import.
 */

/**
 * A breadcrumb saying "this browser had a session last time".
 *
 * The Firebase SDK is ~135 KB gzipped and the signed-out demo must not pay for
 * it. But a signed-in member reloading the page has to land signed in, and the
 * only way to know that is to ask Firebase — which means loading it.
 *
 * So we leave this flag behind on sign-in and read it on boot. Flag present:
 * load Firebase immediately and restore the session. Flag absent: load nothing
 * until someone actually clicks sign in. The flag is a hint, never an
 * authority — it says nothing about whether the session is still valid, and
 * the real answer always comes from `onAuthStateChanged`.
 */
export const SESSION_HINT_KEY = 'clovara-life.session.v1'

export function readSessionHint(): boolean {
  try {
    return localStorage.getItem(SESSION_HINT_KEY) === '1'
  } catch {
    return false
  }
}

export function writeSessionHint(signedIn: boolean): void {
  try {
    if (signedIn) localStorage.setItem(SESSION_HINT_KEY, '1')
    else localStorage.removeItem(SESSION_HINT_KEY)
  } catch {
    /* private window, blocked storage — the session still works, it just
       won't survive a reload without a round trip */
  }
}

/**
 * Where we stash the address a sign-in link was sent to.
 *
 * Firebase requires the email back when completing the link, as proof the
 * person holding the link is the person who asked for it — otherwise anyone who
 * intercepted the URL could sign in as them. On the same device we have it; on
 * a different one we have to ask.
 */
export const PENDING_EMAIL_KEY = 'clovara-life.pending-email.v1'

export function readPendingEmail(): string | null {
  try {
    return localStorage.getItem(PENDING_EMAIL_KEY)
  } catch {
    return null
  }
}

export function writePendingEmail(email: string | null): void {
  try {
    if (email) localStorage.setItem(PENDING_EMAIL_KEY, email)
    else localStorage.removeItem(PENDING_EMAIL_KEY)
  } catch {
    /* blocked storage — we will ask for the address instead */
  }
}

/**
 * Does this URL look like a Firebase sign-in link?
 *
 * Deliberately a string test rather than `isSignInWithEmailLink()`, which lives
 * in the SDK. Calling the SDK version would mean loading ~46KB of Firebase on
 * every page load just to answer "no" for every visitor who is not mid-sign-in
 * — which is all of them, including the investor demo. This is the cheap gate
 * in front of that; the SDK still gets the final say once it is loaded.
 *
 * Firebase's own link format is `?apiKey=…&mode=signIn&oobCode=…&lang=…`.
 * Being wrong in the permissive direction costs one unnecessary SDK load;
 * being wrong in the strict direction would strand someone outside their
 * account, so the test is on mode+oobCode and nothing stricter.
 */
export function looksLikeSignInLink(href: string): boolean {
  if (typeof href !== 'string' || !href) return false
  const q = href.indexOf('?')
  if (q === -1) return false
  let params: URLSearchParams
  try {
    params = new URLSearchParams(href.slice(q + 1).split('#')[0])
  } catch {
    return false
  }
  return params.get('mode') === 'signIn' && !!params.get('oobCode')
}

/**
 * Firebase auth error codes → something a pet owner can act on.
 *
 * The SDK's own messages leak implementation detail ("auth/invalid-credential",
 * "INVALID_LOGIN_CREDENTIALS") and some of them are actively misleading. We map
 * the ones a real person will hit and fall back to a plain sentence otherwise —
 * never to a raw code, and never to a blank string.
 */
export function authErrorMessage(code: unknown): string {
  const key = typeof code === 'string' ? code : ''
  switch (key) {
    case 'auth/invalid-email':
      return "That doesn't look like an email address."
    case 'auth/missing-password':
      return 'Enter your password.'
    case 'auth/weak-password':
      return 'Passwords need to be at least six characters.'
    case 'auth/missing-email':
      return 'Enter the email address the link was sent to.'
    case 'auth/email-already-in-use':
      return 'There is already an account with that email. Try signing in instead.'
    // Firebase deliberately collapses "wrong password" and "no such user" into
    // one code so an attacker cannot enumerate accounts. Our copy has to keep
    // that ambiguity rather than guess which one it was.
    case 'auth/invalid-credential':
    case 'auth/invalid-login-credentials':
    case 'auth/wrong-password':
    case 'auth/user-not-found':
      return "That email and password don't match an account."
    case 'auth/invalid-action-code':
      return 'That sign-in link has already been used. Ask for a fresh one.'
    case 'auth/expired-action-code':
      return 'That sign-in link has expired. Ask for a fresh one and it will work.'
    case 'auth/invalid-email-link':
      return "That link doesn't look complete. Try opening it again from the email itself."
    case 'auth/too-many-requests':
      return 'Too many attempts from this device. Wait a minute and ask for the link again.'
    case 'auth/network-request-failed':
      return 'Could not reach the server. Check your connection and try again.'
    case 'auth/popup-closed-by-user':
    case 'auth/cancelled-popup-request':
      return 'Sign-in window closed before it finished.'
    case 'auth/popup-blocked':
      return 'Your browser blocked the sign-in window. Allow popups for this site and try again.'
    case 'auth/unauthorized-domain':
      return 'This site is not on the project’s authorised domain list yet.'
    case 'auth/operation-not-allowed':
      return 'That sign-in method is not enabled for this project yet.'
    default:
      return 'Something went wrong signing you in. Try again in a moment.'
  }
}

/** Pulls the `code` off whatever the SDK threw, without trusting its shape. */
export function errorCode(err: unknown): string {
  if (err && typeof err === 'object' && 'code' in err) {
    const c = (err as { code: unknown }).code
    if (typeof c === 'string') return c
  }
  return ''
}

/**
 * Good enough to catch a typo before we spend a network round trip on it.
 * Deliberately permissive — the server is the authority on what is deliverable,
 * and an over-strict regex that rejects a real address is worse than a wasted
 * request.
 */
export function looksLikeEmail(value: string): boolean {
  const v = value.trim()
  return v.length >= 5 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v)
}

/** What to call someone in the UI when they may not have set a display name. */
export function displayNameFor(user: { displayName?: string | null; email?: string | null }): string {
  const name = user.displayName?.trim()
  if (name) return name
  const email = user.email?.trim()
  if (email) return email.split('@')[0]
  return 'your account'
}
