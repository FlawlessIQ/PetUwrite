import { useEffect, useState } from 'react'
import { EMAIL_MOMENTS_ENABLED, getEmailPrefs, setEmailPrefs } from '../store/emailPrefs'

/**
 * "Email me when something is due" (Phase B, AO6) — in the account panel.
 *
 * Off unless turned on: a regular email is a different consent from signing up
 * (DECISIONS, X4). Built in only when EMAIL_MOMENTS_ENABLED; until the Life
 * functions are deployed and a domain exists it renders nothing.
 */
export function EmailReminders() {
  const [on, setOn] = useState<boolean | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!EMAIL_MOMENTS_ENABLED) return
    getEmailPrefs()
      .then((p) => setOn(p.moments))
      .catch(() => setError('Could not load your reminder setting.'))
  }, [])

  if (!EMAIL_MOMENTS_ENABLED) return null

  const toggle = async () => {
    if (on === null) return
    setBusy(true)
    setError(null)
    try {
      setOn((await setEmailPrefs(!on)).moments)
    } catch {
      setError('That did not save. Try again in a moment.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="flex items-start justify-between gap-4">
      <div className="min-w-0">
        <p id="email-reminders-label" className="text-body-lg font-medium text-ink">
          Email me when something is due
        </p>
        <p className="mt-0.5 text-body-sm leading-relaxed text-ink-2">
          Vaccination windows, the socialisation window, the yearly check and Gotcha Day. Never more
          than three a day, one tap to stop, and off unless you turn it on.
        </p>
        {error && (
          <p className="mt-1 text-body-sm text-amber" role="alert">
            {error}
          </p>
        )}
      </div>
      <button
        type="button"
        role="switch"
        aria-checked={on === true}
        aria-labelledby="email-reminders-label"
        disabled={on === null || busy}
        onClick={toggle}
        className={`relative mt-1 h-7 w-12 shrink-0 rounded-full transition disabled:opacity-50 ${on ? 'bg-forest' : 'bg-line'}`}
      >
        <span
          aria-hidden="true"
          className={`absolute top-1 h-5 w-5 rounded-full bg-white shadow transition-all ${on ? 'left-6' : 'left-1'}`}
        />
      </button>
    </div>
  )
}
