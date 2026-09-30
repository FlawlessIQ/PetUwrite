import { useEffect, useState } from 'react'
import { cardContentFromLink, type CardLinkFields } from '../share/cardLink'
import { renderShareCard } from '../share/renderCard'
import { track } from '../analytics/track'

/**
 * What a shared card's link opens (ACQUISITION-ONBOARDING-PLAN, AO9).
 *
 * The card, redrawn from the words in the link — never the photograph, which
 * stayed on the sharer's phone — and one invitation: make one for your own.
 * Nothing about the sharer or their pet beyond what they chose to send.
 */
export function SharedCard({
  fields,
  onStart,
  onExample,
}: {
  fields: CardLinkFields | null
  onStart: () => void
  onExample: () => void
}) {
  const [src, setSrc] = useState<string | null>(null)

  useEffect(() => {
    track('shared_link_opened', { kind: fields?.kind ?? 'invalid' })
    if (!fields) return
    let url: string | null = null
    let cancelled = false
    void renderShareCard(cardContentFromLink(fields)).then((blob) => {
      if (cancelled || !blob) return
      url = URL.createObjectURL(blob)
      setSrc(url)
    })
    return () => {
      cancelled = true
      if (url) URL.revokeObjectURL(url)
    }
  }, [fields])

  const yours = 'your dog or cat'
  return (
    <section className="mx-auto flex w-full max-w-[560px] flex-col px-5 pb-16 pt-8 sm:pt-12" aria-labelledby="shared-card-heading">
      {fields ? (
        <>
          <h1 id="shared-card-heading" className="sr-only">
            {fields.kind === 'gotcha' ? `${fields.name}’s Gotcha Day` : `${fields.name}’s plan begins today`}
          </h1>
          <div className="mx-auto w-full max-w-[380px]">
            {src ? (
              <img
                src={src}
                alt={`${fields.name}, ${fields.breedName}, ${fields.ageLabel}. ${cardContentFromLink(fields).headline}`}
                className="w-full rounded-card shadow-lift"
              />
            ) : (
              <div className="aspect-square w-full animate-pulse rounded-card bg-cream-2" aria-hidden="true" />
            )}
          </div>
          <p className="mt-6 text-center text-lead leading-relaxed text-ink-2">
            Made with Clovara Life. Tell us five things about {yours} and see the healthy years ahead of
            them — about a minute, and no account needed.
          </p>
        </>
      ) : (
        <>
          <h1 id="shared-card-heading" className="font-display text-display-sm leading-tight text-ink">
            This link is not complete
          </h1>
          <p className="mt-3 text-lead leading-relaxed text-ink-2">
            Part of it may have been cut off when it was copied. You can still make a plan for {yours}.
          </p>
        </>
      )}
      <div className="mt-6 flex flex-col gap-3 sm:flex-row sm:justify-center">
        <button type="button" className="pill-primary" onClick={onStart}>
          Make one for {yours}
        </button>
        <button type="button" className="pill-ghost" onClick={onExample}>
          See an example first
        </button>
      </div>
    </section>
  )
}
