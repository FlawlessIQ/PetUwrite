import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react'
import type { ReactNode } from 'react'
import { loadAuth, type User } from './firebase'
import { authErrorMessage, errorCode, readSessionHint, writeSessionHint } from './session'

/**
 * `idle`      — the SDK has never been loaded. This is where a signed-out
 *               visitor stays for the whole session, and it is the state the
 *               investor demo runs in.
 * `restoring` — a session hint was found on boot; we are asking Firebase.
 * `working`   — an interactive sign-in, sign-up or sign-out is in flight.
 * `signedIn` / `signedOut` — settled, and Firebase has told us so.
 */
export type AuthStatus = 'idle' | 'restoring' | 'working' | 'signedIn' | 'signedOut'

interface AuthValue {
  user: User | null
  status: AuthStatus
  error: string | null
  clearError: () => void
  signIn: (email: string, password: string) => Promise<boolean>
  signUp: (email: string, password: string) => Promise<boolean>
  signInWithGoogle: () => Promise<boolean>
  sendReset: (email: string) => Promise<boolean>
  signOut: () => Promise<void>
}

const Ctx = createContext<AuthValue | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [status, setStatus] = useState<AuthStatus>(() =>
    readSessionHint() ? 'restoring' : 'idle',
  )
  const [error, setError] = useState<string | null>(null)
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
      })
    }
    return kit
  }, [])

  // Boot: only touches the network if this browser had a session last time.
  useEffect(() => {
    if (!readSessionHint()) return
    ensureWatching().catch(() => {
      if (!mounted.current) return
      // Offline, or the SDK failed to load. Not being able to *confirm* a
      // session is not the same as being signed out, but for everything the UI
      // does it has to be treated that way.
      setStatus('signedOut')
      writeSessionHint(false)
    })
  }, [ensureWatching])

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
      clearError: () => setError(null),
      signIn: (email, password) => run((k) => k.signInWithEmail(email, password)),
      signUp: (email, password) => run((k) => k.createAccount(email, password)),
      signInWithGoogle: () => run((k) => k.signInWithGoogle()),
      sendReset: (email) => run((k) => k.sendReset(email)),
      signOut: async () => {
        await run((k) => k.signOut())
      },
    }),
    [user, status, error, run],
  )

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>
}

export function useAuth(): AuthValue {
  const v = useContext(Ctx)
  if (!v) throw new Error('useAuth must be used inside <AuthProvider>')
  return v
}
