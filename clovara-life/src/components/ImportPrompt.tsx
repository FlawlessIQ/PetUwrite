import type { PetProfile } from '../data/types'

/**
 * "Keep working with Max?" — SPEC §3's one-tap import.
 *
 * Shown when someone signs in on a device that already has pets the account has
 * never seen. Deliberately a banner rather than a modal: they came here to do
 * something, and a wall in front of it would be worse than a slightly stale pet
 * list. Dismissing is free and does not delete anything.
 */
export function ImportPrompt({
  pets,
  busy,
  onImport,
  onDismiss,
}: {
  pets: PetProfile[]
  busy: boolean
  onImport: () => void
  onDismiss: () => void
}) {
  const names = pets.map((p) => p.name)
  const list =
    names.length === 1
      ? names[0]
      : names.length === 2
        ? `${names[0]} and ${names[1]}`
        : `${names.slice(0, -1).join(', ')} and ${names[names.length - 1]}`

  return (
    <div className="mx-auto w-full max-w-shell px-5 pt-5">
      <section
        aria-labelledby="import-heading"
        className="card overflow-hidden border-forest/30 bg-sage/40"
      >
        <div className="flex flex-col gap-4 px-5 py-4 sm:flex-row sm:items-center sm:justify-between sm:px-6">
          <div>
            <h2 id="import-heading" className="font-display text-[19px] leading-tight text-ink">
              Keep working with {list}?
            </h2>
            <p className="mt-1 max-w-[56ch] text-[14px] leading-snug text-ink-2">
              {names.length === 1 ? 'This pet was' : 'These pets were'} made on this device before
              you signed in. Move {names.length === 1 ? 'them' : 'them'} into your account and{' '}
              {names.length === 1 ? 'their plan follows' : 'their plans follow'} you to every device.
            </p>
          </div>
          <div className="flex shrink-0 items-center gap-3">
            <button
              type="button"
              onClick={onDismiss}
              disabled={busy}
              className="text-[14.5px] text-ink-2 transition hover:text-ink disabled:opacity-40 text-action"
            >
              Not now
            </button>
            <button type="button" onClick={onImport} disabled={busy} className="pill-primary disabled:opacity-50">
              {busy ? 'Moving…' : 'Keep them'}
            </button>
          </div>
        </div>
      </section>
    </div>
  )
}
