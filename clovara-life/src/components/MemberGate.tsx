import type { ReactNode } from 'react'

/**
 * The line between what a member gets and what everyone else sees.
 *
 * It never hides the thing behind it. SPEC §1 makes the reveal the hook — the
 * product has to be visible to be wanted — so a gated surface shows what is
 * there and says what unlocks it. Hiding member pricing would make the page
 * emptier and the offer weaker at the same time.
 */
export function MemberGate({
  reason,
  busy,
  onStart,
  children,
}: {
  /** One line, specific to this surface, on what membership changes here. */
  reason: string
  busy: boolean
  onStart: () => void
  /** The gated content, shown but not usable. */
  children?: ReactNode
}) {
  return (
    <div className="rounded-soft border border-forest/25 bg-sage/30 p-4">
      {children && <div className="pointer-events-none mb-3 opacity-55">{children}</div>}
      <p className="text-body-lg leading-relaxed text-ink/85">{reason}</p>
      <div className="mt-3 flex flex-wrap items-center gap-3">
        <button type="button" onClick={onStart} disabled={busy} className="pill-primary disabled:opacity-50">
          {busy ? 'One moment…' : 'Start 7-day free trial'}
        </button>
        <span className="text-body-sm text-ink-2">
          Then $22.99 a month. Cancel any time — it takes one tap.
        </span>
      </div>
    </div>
  )
}

/**
 * Trial-ending nudge. SPEC §3 wants the trial-end lifecycle covered; this is
 * the in-app half of it, and the email is the other.
 */
export function TrialBanner({
  daysLeft,
  onManage,
}: {
  daysLeft: number
  onManage: () => void
}) {
  return (
    <div className="mx-auto w-full max-w-shell px-5 pt-5">
      <div className="card flex flex-col gap-3 border-forest/25 bg-sage/30 px-5 py-4 sm:flex-row sm:items-center sm:justify-between">
        <p className="text-body-lg leading-snug text-ink/85">
          {daysLeft === 0
            ? 'Your free trial ends today. Your membership starts tomorrow at $22.99 a month.'
            : `${daysLeft} day${daysLeft === 1 ? '' : 's'} left of your free trial. After that it's $22.99 a month.`}
        </p>
        <button
          type="button"
          onClick={onManage}
          className="shrink-0 self-start text-body-lg text-forest hover:text-deep sm:self-auto text-action"
        >
          Manage membership
        </button>
      </div>
    </div>
  )
}
