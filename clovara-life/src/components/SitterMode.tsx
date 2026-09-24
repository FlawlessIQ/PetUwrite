import { useEffect, useState } from 'react'
import type { PetProfile } from '../data/types'
import {
  createSitterLink,
  listSitterLinks,
  revokeSitterLink,
  sitterShareUrl,
  type SitterLink,
} from '../store/sitter'
import { longDate } from '../share/cardLayout'
import { track } from '../analytics/track'

/**
 * Sitter Mode (SPEC §6.6) — the owner's half.
 *
 * The card is shown before the link is made. Somebody about to hand a URL to a
 * neighbour should see exactly what that URL shows first, because this is the
 * only thing in the product that leaves the household without a sign-in.
 */
const FIELDS: { key: keyof NonNullable<PetProfile['careNotes']>; label: string; placeholder: string }[] = [
  { key: 'feeding', label: 'Feeding', placeholder: 'Two scoops morning and evening, no treats after six.' },
  { key: 'meds', label: 'Medication', placeholder: 'Half a tablet with breakfast.' },
  { key: 'quirks', label: 'Quirks', placeholder: 'Hates the hoover. Will not go out in rain.' },
  { key: 'vetName', label: 'Vet', placeholder: 'Riverside Vets' },
  { key: 'vetPhone', label: 'Vet phone', placeholder: '01234 567890' },
  { key: 'emergencyName', label: 'Emergency contact', placeholder: 'Jo next door' },
  { key: 'emergencyPhone', label: 'Their phone', placeholder: '07700 900000' },
]

export function SitterMode({
  pet,
  signedIn,
  onUpdate,
}: {
  pet: PetProfile
  signedIn: boolean
  onUpdate?: (patch: Partial<PetProfile>) => void
}) {
  const [notes, setNotes] = useState(pet.careNotes ?? {})
  const [links, setLinks] = useState<SitterLink[]>([])
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [copied, setCopied] = useState<string | null>(null)

  useEffect(() => {
    if (!signedIn) return
    listSitterLinks()
      .then((l) => setLinks(l.filter((x) => x.petId === pet.id)))
      .catch(() => setLinks([]))
  }, [signedIn, pet.id])

  const save = () => {
    onUpdate?.({ careNotes: notes })
  }

  const make = async () => {
    setBusy(true)
    setError(null)
    try {
      save()
      const { token } = await createSitterLink(pet.id, 7)
      setLinks(await listSitterLinks().then((l) => l.filter((x) => x.petId === pet.id)))
      track('sitter_link_created', { pet_is_demo: !!pet.demo, species: pet.species })
      await copy(token)
    } catch {
      setError('We could not make the link. Try again in a moment.')
    } finally {
      setBusy(false)
    }
  }

  const copy = async (token: string) => {
    try {
      await navigator.clipboard.writeText(sitterShareUrl(token))
      setCopied(token)
      setTimeout(() => setCopied(null), 2500)
    } catch {
      /* clipboard refused — the link is on screen to select by hand */
    }
  }

  const revoke = async (token: string) => {
    setBusy(true)
    try {
      await revokeSitterLink(token)
      setLinks((prev) => prev.filter((l) => l.token !== token))
      track('sitter_link_revoked', { pet_is_demo: !!pet.demo })
    } finally {
      setBusy(false)
    }
  }

  return (
    <section className="card overflow-hidden" aria-labelledby="sitter-heading">
      <div className="border-b border-line bg-cream/50 px-5 py-4">
        <p className="label">Sitter mode</p>
        <h2 id="sitter-heading" className="mt-1 font-display text-[20px] text-ink">
          A link for whoever has {pet.name}
        </h2>
        <p className="mt-1 text-[13.5px] leading-relaxed text-muted">
          One page, no sign-in, expires in seven days and can be cancelled any time. It shows only
          what is below — nothing about {pet.name}&rsquo;s plan, their health record, or you.
        </p>
      </div>

      <div className="px-5 py-5">
        <div className="space-y-3.5">
          {FIELDS.map((f) => (
            <div key={f.key}>
              <label htmlFor={`sitter-${f.key}`} className="label">
                {f.label}
              </label>
              <input
                id={`sitter-${f.key}`}
                type="text"
                className="field mt-1.5"
                placeholder={f.placeholder}
                value={notes[f.key] ?? ''}
                onChange={(e) => setNotes((n) => ({ ...n, [f.key]: e.target.value }))}
                onBlur={save}
                disabled={!onUpdate}
              />
            </div>
          ))}
        </div>

        {!signedIn ? (
          <p className="mt-5 rounded-soft bg-sage/60 px-4 py-3 text-[13.5px] leading-relaxed text-deep">
            Sitter links need an account, because the link has to keep working when your phone is in
            your pocket.
          </p>
        ) : (
          <>
            <button
              type="button"
              className="pill-primary mt-5 px-5 py-2.5 text-[14px]"
              onClick={make}
              disabled={busy}
            >
              {busy ? 'One moment…' : 'Make a link'}
            </button>
            {error && <p className="mt-2 text-[13.5px] text-[#8A5510]">{error}</p>}

            {links.length > 0 && (
              <ul className="mt-4 space-y-2">
                {links.map((l) => (
                  <li
                    key={l.token}
                    className="rounded-soft border border-line bg-white px-4 py-3"
                  >
                    <p className="break-all text-[12.5px] text-muted">{sitterShareUrl(l.token)}</p>
                    <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-2">
                      <span className="text-[12.5px] text-muted">
                        Until {longDate(l.expiresAt)}
                      </span>
                      <button
                        type="button"
                        className="text-[13px] text-forest text-action"
                        onClick={() => copy(l.token)}
                      >
                        {copied === l.token ? 'Copied' : 'Copy'}
                      </button>
                      <button
                        type="button"
                        className="text-[13px] text-[#8C1D18] text-action"
                        onClick={() => revoke(l.token)}
                      >
                        Cancel this link
                      </button>
                    </div>
                  </li>
                ))}
              </ul>
            )}
          </>
        )}
      </div>
    </section>
  )
}
