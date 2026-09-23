/**
 * Signs a test user in the way production does: by sending a one-time email
 * link and completing it.
 *
 * Test-only — nothing in `src/` outside `*.emulator.test.ts` imports this.
 *
 * It would be easier to call `createUserWithEmailAndPassword`, and that is what
 * these tests used to do. But password sign-in is no longer part of the product
 * (SPEC §3), so a test that used it would be exercising a path we do not ship —
 * proving the rules work for an identity nobody can actually obtain. The Auth
 * emulator exposes the generated codes over REST, which lets the tests drive the
 * real flow end to end instead.
 */
import type { loadAuth } from '../auth/firebase'

type Kit = Awaited<ReturnType<typeof loadAuth>>

const PROJECT = 'pet-underwriter-ai'
const EMULATOR = 'http://127.0.0.1:9099'

interface OobCode {
  email: string
  oobLink: string
  requestType: string
}

/** Everything the Auth emulator has generated so far, newest last. */
async function fetchOobCodes(): Promise<OobCode[]> {
  const res = await fetch(`${EMULATOR}/emulator/v1/projects/${PROJECT}/oobCodes`)
  if (!res.ok) throw new Error(`Auth emulator returned ${res.status} for oobCodes`)
  const body = (await res.json()) as { oobCodes?: OobCode[] }
  return body.oobCodes ?? []
}

/**
 * Minimal browser globals for code that legitimately needs them.
 *
 * `sendSignInLink` builds its return URL from `window.location` — the link has
 * to come back to the app, so that is not something to stub out of the
 * production path just to make a test easier. The test supplies a location
 * instead. `localStorage` is here for the same reason: `track()` no-ops
 * silently without it, which would make the analytics tests pass while
 * measuring nothing.
 */
export function installBrowserShims(origin = 'http://localhost:4173'): void {
  const g = globalThis as Record<string, unknown>
  if (typeof g.window === 'undefined') {
    g.window = { location: { origin, pathname: '/', href: `${origin}/` } }
  }
  if (typeof g.localStorage === 'undefined') {
    const mem = new Map<string, string>()
    g.localStorage = {
      getItem: (k: string) => mem.get(k) ?? null,
      setItem: (k: string, v: string) => void mem.set(k, String(v)),
      removeItem: (k: string) => void mem.delete(k),
      clear: () => mem.clear(),
      key: (i: number) => [...mem.keys()][i] ?? null,
      get length() {
        return mem.size
      },
    }
  }
}

let seq = 0

/**
 * Creates a brand-new signed-in user and returns their uid.
 *
 * The SDK is left signed in as this user, which is what the rules tests rely on
 * when they call it twice to become "somebody else".
 */
export async function signInFreshViaLink(kit: Kit, prefix = 'p0'): Promise<{ uid: string; email: string }> {
  const email = `${prefix}-${++seq}-${Math.random().toString(36).slice(2, 8)}@example.com`
  await kit.sendSignInLink(email)

  const codes = await fetchOobCodes()
  const mine = codes.filter((c) => c.email === email && c.requestType === 'EMAIL_SIGNIN').pop()
  if (!mine) throw new Error(`No sign-in link was generated for ${email}`)

  const cred = await kit.completeSignInLink(email, mine.oobLink)
  return { uid: cred.user.uid, email }
}
