import { useEffect, useRef, useState } from 'react'
import type { PetProfile } from '../data/types'
import { renderShareCard, arrivalCard, gotchaCard, type CardContent } from '../share/renderCard'
import { shareCardImage } from '../share/shareImage'
import { track } from '../analytics/track'

/**
 * The Arrival Certificate (SPEC §6.1) and Gotcha Day card (§6.7), which share
 * one pipeline because SPEC says they should.
 *
 * It shows the card before offering to share it. A share sheet that opens onto
 * something you have not seen is how people post things they did not mean to,
 * and this one has a photograph of their pet on it.
 */
export function ShareCard({
  pet,
  kind,
  breedName,
  ageLabel,
  years,
  onClose,
}: {
  pet: PetProfile
  kind: 'arrival' | 'gotcha'
  breedName: string
  ageLabel: string
  /** Years home, for the Gotcha Day card. */
  years?: number
  onClose: () => void
}) {
  const [url, setUrl] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [note, setNote] = useState<string | null>(null)
  const blobRef = useRef<Blob | null>(null)

  useEffect(() => {
    let cancelled = false
    let objectUrl: string | null = null
    const base = {
      name: pet.name,
      breedName,
      ageLabel,
      photoUrl: pet.photo?.avatarUrl,
    }
    const content: CardContent =
      kind === 'gotcha' ? gotchaCard(base, years ?? 1, new Date()) : arrivalCard(base, new Date())
    ;(async () => {
      const blob = await renderShareCard(content)
      if (cancelled) return
      if (!blob) {
        setNote('We could not make the card on this device.')
        return
      }
      blobRef.current = blob
      objectUrl = URL.createObjectURL(blob)
      setUrl(objectUrl)
    })()
    return () => {
      cancelled = true
      if (objectUrl) URL.revokeObjectURL(objectUrl)
    }
  }, [pet.name, pet.photo?.avatarUrl, breedName, ageLabel, kind, years])

  const share = async () => {
    if (!blobRef.current) return
    setBusy(true)
    setNote(null)
    const outcome = await shareCardImage(blobRef.current, {
      name: pet.name,
      kind,
      title:
        kind === 'gotcha'
          ? `${pet.name}\u2019s Gotcha Day`
          : `${pet.name}\u2019s plan begins today`,
    })
    setBusy(false)
    track('share_card', { kind, outcome, pet_is_demo: !!pet.demo, has_photo: !!pet.photo })
    if (outcome === 'downloaded') setNote('Saved to your downloads.')
    if (outcome === 'failed') setNote('That did not work on this device.')
  }

  return (
    <section className="card overflow-hidden" aria-labelledby="share-card-heading">
      <div className="border-b border-line bg-cream/50 px-5 py-4">
        <h2 id="share-card-heading" className="font-display text-[20px] text-ink">
          {kind === 'gotcha'
            ? `${pet.name}\u2019s Gotcha Day`
            : `${pet.name}\u2019s arrival certificate`}
        </h2>
        <p className="mt-1 text-[13.5px] leading-relaxed text-muted">
          Yours to keep or to send. The card is made on your device and never leaves it unless you
          share it.
        </p>
      </div>

      <div className="px-5 py-5">
        <div className="mx-auto w-full max-w-[380px]">
          {url ? (
            <img
              src={url}
              alt={`A card with ${pet.name}'s name and photo`}
              className="w-full rounded-soft border border-line"
            />
          ) : (
            <div
              className="aspect-square w-full animate-pulse rounded-soft bg-cream"
              aria-label="Making the card"
            />
          )}
        </div>

        {note && <p className="mt-3 text-center text-[13.5px] text-muted">{note}</p>}

        <div className="mt-5 flex flex-wrap justify-center gap-2">
          <button
            type="button"
            className="pill-primary px-5 py-2.5 text-[14px]"
            onClick={share}
            disabled={!url || busy}
          >
            {busy ? 'One moment…' : 'Save or share'}
          </button>
          <button
            type="button"
            className="pill-ghost px-5 py-2.5 text-[14px]"
            onClick={onClose}
          >
            Not now
          </button>
        </div>
      </div>
    </section>
  )
}
