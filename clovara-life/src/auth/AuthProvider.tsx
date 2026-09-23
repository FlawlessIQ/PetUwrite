import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react'
import type { ReactNode } from 'react'
import { loadAuth, type User } from './firebase'
import {
  authErrorMessage,
  errorCode,
  looksLikeSignInLink,
  readPendingEmail,
  readSessionHint,
  writePendingEmail,
  writeSessionHint,
} from './session'
import { flush, track } from '../analytics/track'

/**
 * `idle`      — the SDK has never been loaded. This is where a signed-out
 *               visitor stays for the whole session, and it is the state the
 *               investor demo runs in.
 * `restoring` — a session hint or a sign-in link was found on boot.
 * `working`   — an interactive sign-in or sign-out is in flight.
 * `signedIn` / `signedOut` — settled, and Firebase has told us so.
 */
export type AuthStatus = 'idle' | 'restoring' | 'working' | 'signedIn' | 'signedOut'

interface AuthValue {
  user: User | null
  status: AuthStatus
  error: string | null
  clearError: () => void
  /** Emails a one-time sign-in link. Creates the account if there isn't one. */
  sendLink: (email: string) => Promise<boolean>
  signInWithGoogle: () => Promise<boolean>
  signOut: () => Promise<void>
  /**
   * A sign-in link is open but we do not know which address it was sent to —
   * they opened it on a different device from the one that asked. Firebase
   * requires the address back as proof the holder of the link is the person who
   * requested it, so the UI has to ask.
   */
  needsEmailForLink: boolean
  completeLinkWithEmail: (email: string) => Promise<boolean>
}

const Ctx = createContext<AuthValue | null>(null)

/** Strips Firebase's one-time parameters so a reload cannot replay a used code. */
function cleanLinkFromUrl(): void {
  try {
    const url = new URL(window.location.href)
    for (const k of ['apiKey', 'mode', 'oobCode', 'continueUrl', 'lang', 'tenantId']) {
      url.searchParams.delete(k)
    }
    window.history.replaceState(null, '', `${url.pathname}${url.search}${url.hash}`)
  } catch {
    /* Non-fatal: the worst case is an ugly URL. */
  }
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [status, setStatus] = useState<AuthStatus>(() =>
    readSessionHint() || looksLikeSignInLink(window.location.href) ? 'restoring' : 'idle',
  )
  const [error, setError] = useState<string | null>(null)
  const [needsEmailForLink, setNeedsEmailForLink] = useState(false)
  const unwatch = useRef<(() => void) | null>(null)
  const mounted = useRef(true)

  useEffect(() => {
    mounted.current = true
    return () => {
      mounted.current = false
      unwatch.current?.()
    }
  }, [])

  /**
   * Attaches the auth listener, loading the SDK if it is not already in. Every
   * entry point goes through here so there is exactly one listener and one
   * place that decides what `status` becomes.
   */
  const ensureWatching = useCallback(async () => {
    const kit = await loadAuth()
    if (!mounted.current) return kit
    if (!unwatch.current) {
      unwatch.current = kit.watch((u) => {
        if (!mounted.current) return
        setUser(u)
        setStatus(u ? 'signedIn' : 'signedOut')
        writeSessionHint(!!u)
        // The moment there is an identity, everything buffered against this
        // browser's visitorId can be written and attributed — including the
        // pre-account reveal that is the top of the funnel.
        if (u) void flush(u.uid)
      })
    }
    return kit
  }, [])

  /** Records an auth event and flushes it, since the watcher's flush already ran. */
  const trackAuth = useCallback(async (name: 'signed_in' | 'signed_up', method: string) => {
    track(name, { method })
    try {
      const uid = (await loadAuth()).auth.currentUser?.uid
      if (uid) await flush(uid)
    } catch {
      /* The event stays queued and goes out with the next flush. */
    }
  }, [])

  /**
   * Boot. Loads the SDK for exactly two reasons: this browser had a session, or
   * the URL we landed on is a sign-in link. `looksLikeSignInLink` is a pure
   * string test, so the check itself costs nothing — every other visitor,
   * including the investor demo, loads no Firebase at all.
   */
  useEffect(() => {
    const isLink = looksLikeSignInLink(window.location.href)
    if (!readSessionHint() && !isLink) return
    void (async () => {
      try {
        const kit = await ensureWatching()
        if (!isLink || !mounted.current) return
        // The SDK gets the authoritative say now that it is here.
        if (!kit.isSignInLink(window.location.href)) return
        const pending = readPendingEmail()
        if (!pending) {
          setNeedsEmailForLink(true)
          setStatus('signedOut')
          return
        }
        setStatus('working')
        await kit.completeSignInLink(pending, window.location.href)
        writePendingEmail(null)
        cleanLinkFromUrl()
        await trackAuth('signed_in', 'email_link')
      } catch (err) {
        if (!mounted.current) return
        setError(authErrorMessage(errorCode(err)))
        setStatus('signedOut')
        writeSessionHint(false)
        // A dud link must not leave the app trying to complete it on every
        // reload — strip it so the next load is a clean one.
        cleanLinkFromUrl()
      }
    })()
  }, [ensureWatching, trackAuth])

  /** Every interactive auth call funnels through this: one place for errors. */
  const run = useCallback(
    async (fn: (kit: Awaited<ReturnType<typeof loadAuth>>) => Promise<unknown>) => {
      setError(null)
      setStatus('working')
      try {
        const kit = await ensureWatching()
        await fn(kit)
        return true
      } catch (err) {
        if (mounted.current) {
          setError(authErrorMessage(errorCode(err)))
          setStatus(user ? 'signedIn' : 'signedOut')
        }
        return false
      }
    },
    [ensureWatching, user],
  )

  const value = useMemo<AuthValue>(
    () => ({
      user,
      status,
      error,
      needsEmailForLink,
      clearError: () => setError(null),
      sendLink: async (email) => {
        const ok = await run((k) => k.sendSignInLink(email))
        if (ok) {
          // Remembered so the same device does not have to re-type it. This is
          // the only copy — the address is never put in the link itself.
          writePendingEmail(email.trim())
          // Sending a link is not signing in. Status goes back to where it was.
          setStatus(user ? 'signedIn' : 'signedOut')
          track('signed_up', { method: 'email_link_requested' })
        }
        return ok
      },
      completeLinkWithEmail: async (email) => {
        const ok = await run((k) => k.completeSignInLink(email, window.location.href))
        if (ok) {
          writePendingEmail(null)
          cleanLinkFromUrl()
          setNeedsEmailForLink(false)
          await trackAuth('signed_in', 'email_link_other_device')
        }
        return ok
      },
      signInWithGoogle: async () => {
        const ok = await run((k) => k.signInWithGoogle())
        if (ok) await trackAuth('signed_in', 'google')
        return ok
      },
      signOut: async () => {
        await run((k) => k.signOut())
      },
    }),
    [user, status, error, needsEmailForLink, run, trackAuth],
  )

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>
}

export function useAuth(): AuthValue {
  const v = useContext(Ctx)
  if (!v) throw new Error('useAuth must be used inside <AuthProvider>')
  return v
}
