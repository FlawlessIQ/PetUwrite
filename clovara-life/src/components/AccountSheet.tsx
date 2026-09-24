import { useEffect, useRef, useState } from 'react'
import { useAuth } from '../auth/AuthProvider'
import { displayNameFor, looksLikeEmail } from '../auth/session'
import { CloverMark } from './CloverMark'
import { isMember, trialDaysLeft, type Entitlement } from '../store/membership'
import { FamilyCircle } from './FamilyCircle'

/**
 * The account panel. Deliberately a modal rather than a route: signing in is
 * never a precondition for using Clovara Life, so it must never take over the
 * URL or interrupt a demo. Escape and the backdrop both close it.
 *
 * No passwords (SPEC §3). A one-time link or Google — nothing for anyone to
 * choose badly, forget, or reuse from another site.
 */
export function AccountSheet({
  onClose,
  entitlement,
  onManage,
  onStartTrial,
  membershipBusy,
  membershipError,
  memberCount,
}: {
  onClose: () => void
  entitlement: Entitlement
  onManage: () => void
  onStartTrial: () => void
  membershipBusy: boolean
  membershipError: string | null
  memberCount: number
}) {
  const {
    user,
    status,
    error,
    clearError,
    sendLink,
    signInWithGoogle,
    signOut,
    needsEmailForLink,
    completeLinkWithEmail,
  } = useAuth()
  const [email, setEmail] = useState('')
  const [sent, setSent] = useState(false)
  const busy = status === 'working' || status === 'restoring'
  const firstField = useRef<HTMLInputElement>(null)

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose()
    document.addEventListener('keydown', onKey)
    firstField.current?.focus()
    return () => document.removeEventListener('keydown', onKey)
  }, [onClose])

  const submit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (busy || !looksLikeEmail(email)) return
    if (needsEmailForLink) {
      if (await completeLinkWithEmail(email)) onClose()
      return
    }
    if (await sendLink(email)) setSent(true)
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center bg-ink/30 px-4 py-6 backdrop-blur-sm sm:items-center"
      onMouseDown={(e) => e.target === e.currentTarget && onClose()}
    >
      <div
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
            <p className="text-[13.5px] leading-relaxed text-muted">{user.email}</p>

            <div className="rounded-soft border border-line bg-cream/60 p-4">
              <p className="label mb-1.5">Membership</p>
              <p className="text-[14.5px] leading-relaxed text-ink/85">{membershipLine(entitlement)}</p>
              {membershipError && (
                <p role="alert" className="mt-2 text-[13.5px] text-[#8A5510]">
                  {membershipError}
                </p>
              )}
              <button
                type="button"
                onClick={isMember(entitlement) ? onManage : onStartTrial}
                disabled={membershipBusy}
                className="mt-3 text-[14px] text-forest transition hover:text-deep disabled:opacity-40 text-action"
              >
                {membershipBusy
                  ? 'One moment…'
                  : isMember(entitlement)
                    ? 'Manage, change card, or cancel'
                    : 'Start your 7-day free trial'}
              </button>
            </div>

            <FamilyCircle memberCount={memberCount} />

            {/* Invariant 5: linked from settings. */}
            <a
              href="#/covenant"
              onClick={onClose}
              className="block text-[14px] text-forest transition hover:text-deep text-action"
            >
              The Data Covenant
            </a>

            <div className="flex items-center justify-between gap-3 border-t border-line pt-5">
              <button
                type="button"
                onClick={async () => {
                  await signOut()
                  onClose()
                }}
                disabled={busy}
                className="text-[14.5px] text-muted transition hover:text-ink disabled:opacity-40 text-action"
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
                  {needsEmailForLink ? 'Confirm your email' : 'Sign in to Clovara'}
                </h2>
              </div>
              <p className="text-[14.5px] leading-snug text-muted">
                {needsEmailForLink
                  ? 'You opened the link on a different device. Type the address you asked for it with and we can finish.'
                  : 'Your pets and their plans, on every device you use. No password to remember.'}
              </p>
            </div>

            {sent ? (
              <div className="space-y-4">
                <div className="rounded-soft border border-line bg-sage/50 p-4 text-[14.5px] leading-relaxed text-deep">
                  Check <span className="font-medium">{email.trim()}</span> — there's a sign-in link
                  waiting. Open it on this device and you'll land straight back here.
                </div>
                <button
                  type="button"
                  onClick={() => {
                    setSent(false)
                    clearError()
                  }}
                  className="text-[14px] text-forest hover:text-deep text-action"
                >
                  Use a different address
                </button>
              </div>
            ) : (
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
              <button
                type="submit"
                disabled={!looksLikeEmail(email) || busy}
                className="pill-primary w-full justify-center disabled:cursor-not-allowed disabled:opacity-50"
              >
                {busy
                  ? 'One moment…'
                  : needsEmailForLink
                    ? 'Finish signing in'
                    : 'Email me a sign-in link'}
              </button>
            )}

            {!needsEmailForLink && !sent && (
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

            <div className="flex items-center justify-end border-t border-line pt-4 text-[14px]">
              <button
                type="button"
                onClick={onClose}
                className="text-muted hover:text-ink text-action"
              >
                Not now
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  )
}

/**
 * Says where the membership stands in plain words.
 *
 * `past_due` deliberately does not say "expired" or "cancelled" — nothing has
 * been lost yet, Stripe is still retrying, and telling someone they have been
 * cut off when they have not is how a card problem becomes a cancellation.
 */
function membershipLine(e: Entitlement): string {
  const days = trialDaysLeft(e, new Date())
  switch (e.status) {
    case 'trialing':
      return days === null
        ? 'Free trial running.'
        : days === 0
          ? 'Your free trial ends today, then $22.99 a month.'
          : `${days} day${days === 1 ? '' : 's'} left of your free trial, then $22.99 a month.`
    case 'active':
      return e.cancelAtPeriodEnd
        ? 'Active, and set to end at the close of this billing period.'
        : 'Active. $22.99 a month.'
    case 'past_due':
      return "Your last payment didn't go through. We're still trying — nothing has been lost, and updating your card fixes it."
    case 'canceled':
      return 'Cancelled. Start again whenever you like.'
    case 'incomplete':
    case 'unpaid':
      return 'Your membership needs a payment method before it can start.'
    default:
      return 'No membership yet. The plan and the reveal are free to look at.'
  }
}
