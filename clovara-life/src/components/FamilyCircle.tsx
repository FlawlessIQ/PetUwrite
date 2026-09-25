import { useState } from 'react'
import { createInvite, inviteError, redeemInvite } from '../store/household'

/**
 * The family circle, in settings (SPEC §4.3).
 *
 * v1 is deliberately small: invite someone, or join with a code. Roles exist on
 * the household document but nothing reads them yet — SPEC says "v1: anyone can
 * answer", so showing a role picker would imply a distinction the product does
 * not yet make.
 */
export function FamilyCircle({ memberCount }: { memberCount: number }) {
  const [code, setCode] = useState<string | null>(null)
  const [expires, setExpires] = useState(7)
  const [joining, setJoining] = useState(false)
  const [entry, setEntry] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [joined, setJoined] = useState(false)
  const [copied, setCopied] = useState(false)

  const invite = async () => {
    setBusy(true)
    setError(null)
    try {
      const r = await createInvite()
      setCode(r.code)
      setExpires(r.expiresInDays)
    } catch (err) {
      setError(inviteError(err))
    } finally {
      setBusy(false)
    }
  }

  const join = async () => {
    setBusy(true)
    setError(null)
    try {
      await redeemInvite(entry)
      setJoined(true)
    } catch (err) {
      setError(inviteError(err))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="rounded-soft border border-line bg-cream/60 p-4">
      <p className="label mb-1.5">Family circle</p>
      <p className="text-body-lg leading-relaxed text-ink/85">
        {memberCount <= 1
          ? "It's just you so far. Anyone you add sees the same pets and can answer the same questions."
          : `${memberCount} people share these pets.`}
      </p>

      {joined && (
        <p className="mt-3 rounded-soft border border-forest/25 bg-sage/40 px-3 py-2 text-body-lg text-deep">
          You're in. Reload to see their pets.
        </p>
      )}

      {code && (
        <div className="mt-3 rounded-soft border border-forest/25 bg-sage/30 px-3 py-3">
          <p className="text-body-sm text-ink-2">Give them this code:</p>
          <p className="mt-1 select-all font-display text-display-sm tracking-[0.06em] text-deep">
            {code}
          </p>
          <div className="mt-2 flex flex-wrap items-center gap-3">
            <button
              type="button"
              onClick={() => {
                navigator.clipboard?.writeText(code).then(
                  () => setCopied(true),
                  () => setCopied(false),
                )
              }}
              className="text-body text-forest hover:text-deep text-action"
            >
              {copied ? 'Copied' : 'Copy'}
            </button>
            <span className="text-body-sm text-ink-2">
              Works once, for {expires} days. Then it stops working.
            </span>
          </div>
        </div>
      )}

      {error && (
        <p role="alert" className="mt-3 text-body leading-relaxed text-[#8A5510]">
          {error}
        </p>
      )}

      {!joining ? (
        <div className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-2">
          <button
            type="button"
            onClick={invite}
            disabled={busy}
            className="text-body-lg text-forest transition hover:text-deep disabled:opacity-40 text-action"
          >
            {busy ? 'One moment…' : code ? 'Make another code' : 'Invite someone'}
          </button>
          <button
            type="button"
            onClick={() => {
              setJoining(true)
              setError(null)
            }}
            className="text-body-lg text-ink-2 transition hover:text-ink text-action"
          >
            I have a code
          </button>
        </div>
      ) : (
        <div className="mt-3">
          <label htmlFor="join-code" className="label mb-1.5 block">
            Their code
          </label>
          <div className="flex flex-wrap gap-2">
            <input
              id="join-code"
              className="field max-w-[11rem] uppercase tracking-[0.08em]"
              value={entry}
              onChange={(e) => setEntry(e.target.value.toUpperCase())}
              placeholder="ABCD-2345"
              autoComplete="off"
            />
            <button
              type="button"
              onClick={join}
              disabled={busy || entry.trim().length < 8}
              className="pill-primary disabled:opacity-50"
            >
              {busy ? 'Checking…' : 'Join'}
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
