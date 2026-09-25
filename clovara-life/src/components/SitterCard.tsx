import { useEffect, useState } from 'react'
import { readSitterCard, type SitterCard as Card } from '../store/sitter'
import { CloverMark } from './CloverMark'
import { longDate } from '../share/cardLayout'

/**
 * What a sitter sees (SPEC §6.6).
 *
 * The one page in the product rendered for somebody who is not signed in and
 * may never be. It loads no auth, no pets, and no engine — a fetch and some
 * text. Expired, revoked and never-existed all render the same thing, because
 * telling them apart would make this page an oracle for guessing tokens.
 */
export function SitterCard({ token }: { token: string }) {
  const [state, setState] = useState<'loading' | 'gone' | 'ok'>('loading')
  const [card, setCard] = useState<Card | null>(null)
  const [expires, setExpires] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    readSitterCard(token).then((r) => {
      if (cancelled) return
      if (!r) {
        setState('gone')
        return
      }
      setCard(r.card)
      setExpires(r.expiresAt)
      setState('ok')
    })
    return () => {
      cancelled = true
    }
  }, [token])

  const rows: { label: string; value: string | null; tel?: string | null }[] = card
    ? [
        { label: 'Feeding', value: card.feeding },
        { label: 'Medication', value: card.medication },
        { label: 'Worth knowing', value: card.quirks },
        { label: 'Vet', value: card.vetName, tel: card.vetPhone },
        { label: 'If you cannot reach them', value: card.emergencyName, tel: card.emergencyPhone },
      ].filter((r) => r.value || r.tel)
    : []

  return (
    <div className="mx-auto w-full max-w-[560px] px-5 pb-16 pt-8">
      <div className="mb-6 flex items-center gap-2.5">
        <CloverMark size={26} />
        <span className="font-display text-heading-sm text-ink">Clovara</span>
      </div>

      {state === 'loading' && <p className="text-lead text-ink-2">One moment…</p>}

      {state === 'gone' && (
        <div className="card p-6">
          <h1 className="font-display text-heading-lg text-ink">This link is no longer live</h1>
          <p className="mt-2 text-body-lg leading-relaxed text-ink-2">
            Sitter links last a few days and can be cancelled at any time. Ask whoever sent it for a
            new one.
          </p>
        </div>
      )}

      {state === 'ok' && card && (
        <div className="card overflow-hidden">
          <div className="flex items-center gap-4 border-b border-line bg-cream/50 px-5 py-5">
            {card.photoUrl ? (
              <img
                src={card.photoUrl}
                alt={card.name}
                className="h-16 w-16 shrink-0 rounded-full border border-line object-cover"
              />
            ) : (
              <span className="grid h-16 w-16 shrink-0 place-items-center rounded-full bg-sage font-display text-display-sm text-deep">
                {card.name.slice(0, 1).toUpperCase()}
              </span>
            )}
            <div className="min-w-0">
              <h1 className="font-display text-stat leading-tight text-ink">{card.name}</h1>
              {card.species && <p className="text-body text-ink-2">Looking after a {card.species}</p>}
            </div>
          </div>

          {rows.length > 0 ? (
            <ul className="divide-y divide-line">
              {rows.map((r) => (
                <li key={r.label} className="px-5 py-4">
                  <p className="label">{r.label}</p>
                  {r.value && <p className="mt-1 text-lead leading-relaxed text-ink">{r.value}</p>}
                  {r.tel && (
                    <a
                      href={`tel:${r.tel.replace(/\s+/g, '')}`}
                      className="mt-1 inline-block text-lead font-medium text-forest"
                    >
                      {r.tel}
                    </a>
                  )}
                </li>
              ))}
            </ul>
          ) : (
            <p className="px-5 py-6 text-body-lg leading-relaxed text-ink-2">
              Nothing has been written down yet. Ask whoever sent this for the details.
            </p>
          )}

          <p className="border-t border-line bg-cream/40 px-5 py-4 text-body-sm leading-relaxed text-ink-2">
            Shared with you by {card.name}&rsquo;s family.
            {expires ? ` This page stops working after ${longDate(expires)}.` : ''} In an emergency,
            ring the vet above or your nearest emergency practice.
          </p>
        </div>
      )}
    </div>
  )
}
