import { useEffect, useRef, useState } from 'react'
import { useAuth } from '../auth/AuthProvider'
import { displayNameFor, looksLikeEmail } from '../auth/session'
import { CloverMark } from './CloverMark'

type Mode = 'signIn' | 'signUp' | 'reset'

const COPY: Record<Mode, { title: string; blurb: string; cta: string }> = {
  signIn: {
    title: 'Sign in to Clovara',
    blurb: 'Your pets and their plans, on every device you use.',
    cta: 'Sign in',
  },
  signUp: {
    title: 'Create your Clovara account',
    blurb: 'Free to create. Your pets stay yours.',
    cta: 'Create account',
  },
  reset: {
    title: 'Reset your password',
    blurb: "We'll email you a link to set a new one.",
    cta: 'Send the link',
  },
}

/**
 * The account panel. Deliberately a modal rather than a route: signing in is
 * never a precondition for using Clovara Life, so it must never take over the
 * URL or interrupt a demo. Escape and the backdrop both close it.
 */
export function AccountSheet({ onClose }: { onClose: () => void }) {
  const { user, status, error, clearError, signIn, signUp, signInWithGoogle, sendReset, signOut } =
    useAuth()
  const [mode, setMode] = useState<Mode>('signIn')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [sent, setSent] = useState(false)
  const busy = status === 'working' || status === 'restoring'
  const panel = useRef<HTMLDivElement>(null)
  const firstField = useRef<HTMLInputElement>(null)

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose()
    document.addEventListener('keydown', onKey)
    firstField.current?.focus()
    return () => document.removeEventListener('keydown', onKey)
  }, [onClose])

  const switchTo = (m: Mode) => {
    setMode(m)
    setSent(false)
    clearError()
  }

  const submit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (busy) return
    if (mode === 'reset') {
      if (!looksLikeEmail(email)) return
      if (await sendReset(email)) setSent(true)
      return
    }
    if (!looksLikeEmail(email) || password.length < 6) return
    const ok = mode === 'signIn' ? await signIn(email, password) : await signUp(email, password)
    if (ok) onClose()
  }

  const canSubmit =
    mode === 'reset' ? looksLikeEmail(email) : looksLikeEmail(email) && password.length >= 6

  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center bg-ink/30 px-4 py-6 backdrop-blur-sm sm:items-center"
      onMouseDown={(e) => e.target === e.currentTarget && onClose()}
    >
      <div
        ref={panel}
        role="dialog"
        aria-modal="true"
        aria-labelledby="account-title"
        className="reveal card w-full max-w-[420px] overflow-y-auto p-6 sm:p-7"
        style={{ maxHeight: 'calc(100dvh - 3rem)' }}
      >
        {user ? (
          <div className="space-y-5">
            <div className="flex items-center gap-2.5">
              <CloverMark size={24} id="acct" />
              <h2 id="account-title" className="font-display text-[22px] leading-tight text-ink">
                Signed in
              </h2>
            </div>
            <p className="text-[15px] leading-relaxed text-ink/85">
              You are signed in as{' '}
              <span className="font-medium text-deep">{displayNameFor(user)}</span>.
            </p>
            <p className="text-[13.5px] leading-relaxed text-muted">
              {user.email}
            </p>
            <div className="flex items-center justify-between gap-3 border-t border-line pt-5">
              <button
                type="button"
                onClick={async () => {
                  await signOut()
                  onClose()
                }}
                disabled={busy}
                className="text-[14.5px] text-muted underline underline-offset-4 transition hover:text-ink disabled:opacity-40"
              >
                Sign out
              </button>
              <button type="button" onClick={onClose} className="pill-primary">
                Done
              </button>
            </div>
          </div>
        ) : (
          <form className="space-y-5" onSubmit={submit}>
            <div>
              <div className="mb-2 flex items-center gap-2.5">
                <CloverMark size={24} id="acct" />
                <h2 id="account-title" className="font-display text-[22px] leading-tight text-ink">
                  {COPY[mode].title}
                </h2>
              </div>
              <p className="text-[14.5px] leading-snug text-muted">{COPY[mode].blurb}</p>
            </div>

            {sent ? (
              <div className="rounded-soft border border-line bg-sage/50 p-4 text-[14.5px] leading-relaxed text-deep">
                If there is an account for {email.trim()}, a reset link is on its way. Check spam if
                it has not arrived in a minute.
              </div>
            ) : (
              <>
                <div>
                  <label htmlFor="acct-email" className="label mb-2 block">
                    Email
                  </label>
                  <input
                    id="acct-email"
                    ref={firstField}
                    type="email"
                    autoComplete="email"
                    className="field"
                    value={email}
                    onChange={(e) => {
                      setEmail(e.target.value)
                      clearError()
                    }}
                    placeholder="you@example.com"
                  />
                </div>

                {mode !== 'reset' && (
                  <div>
                    <label htmlFor="acct-password" className="label mb-2 block">
                      Password
                    </label>
                    <input
                      id="acct-password"
                      type="password"
                      autoComplete={mode === 'signUp' ? 'new-password' : 'current-password'}
                      className="field"
                      value={password}
                      onChange={(e) => {
                        setPassword(e.target.value)
                        clearError()
                      }}
                      placeholder={mode === 'signUp' ? 'At least 6 characters' : ''}
                    />
                  </div>
                )}
              </>
            )}

            {error && (
              <p
                role="alert"
                className="rounded-soft border border-accent/30 bg-accent/10 px-3.5 py-2.5 text-[14px] leading-relaxed text-[#8A5510]"
              >
                {error}
              </p>
            )}

            {!sent && (
              <button type="submit" disabled={!canSubmit || busy} className="pill-primary w-full justify-center disabled:cursor-not-allowed disabled:opacity-50">
                {busy ? 'One moment…' : COPY[mode].cta}
              </button>
            )}

            {mode !== 'reset' && (
              <>
                <div className="flex items-center gap-3" aria-hidden="true">
                  <span className="h-px flex-1 bg-line" />
                  <span className="text-[12.5px] uppercase tracking-[0.08em] text-muted">or</span>
                  <span className="h-px flex-1 bg-line" />
                </div>
                <button
                  type="button"
                  disabled={busy}
                  onClick={async () => {
                    if (await signInWithGoogle()) onClose()
                  }}
                  className="flex w-full items-center justify-center gap-2.5 rounded-full border border-line bg-white px-4 py-2.5 text-[15px] font-medium text-ink transition hover:border-forest/50 disabled:opacity-50"
                >
                  <svg aria-hidden="true" width="17" height="17" viewBox="0 0 18 18">
                    <path fill="#4285F4" d="M17.64 9.2c0-.64-.06-1.25-.16-1.84H9v3.48h4.84a4.14 4.14 0 0 1-1.8 2.72v2.26h2.92c1.7-1.57 2.68-3.88 2.68-6.62Z" />
                    <path fill="#34A853" d="M9 18c2.43 0 4.47-.8 5.96-2.18l-2.92-2.26c-.8.54-1.84.86-3.04.86-2.34 0-4.32-1.58-5.03-3.7H.96v2.33A9 9 0 0 0 9 18Z" />
                    <path fill="#FBBC05" d="M3.97 10.72a5.4 5.4 0 0 1 0-3.44V4.95H.96a9 9 0 0 0 0 8.1l3.01-2.33Z" />
                    <path fill="#EA4335" d="M9 3.58c1.32 0 2.5.46 3.44 1.35l2.58-2.58C13.46.9 11.43 0 9 0A9 9 0 0 0 .96 4.95l3.01 2.33C4.68 5.16 6.66 3.58 9 3.58Z" />
                  </svg>
                  Continue with Google
                </button>
              </>
            )}

            <div className="flex flex-wrap items-center justify-between gap-x-4 gap-y-2 border-t border-line pt-4 text-[14px]">
              {mode === 'signIn' && (
                <>
                  <button type="button" onClick={() => switchTo('signUp')} className="text-forest underline underline-offset-4 hover:text-deep">
                    Create an account
                  </button>
                  <button type="button" onClick={() => switchTo('reset')} className="text-muted underline underline-offset-4 hover:text-ink">
                    Forgot password
                  </button>
                </>
              )}
              {mode !== 'signIn' && (
                <button type="button" onClick={() => switchTo('signIn')} className="text-forest underline underline-offset-4 hover:text-deep">
                  Back to sign in
                </button>
              )}
              <button type="button" onClick={onClose} className="ml-auto text-muted underline underline-offset-4 hover:text-ink">
                Not now
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  )
}
