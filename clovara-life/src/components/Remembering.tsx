import { useState } from 'react'
import type { PetProfile } from '../data/types'
import { isRemembered, REMEMBER_BODY, REMEMBER_HEADLINE, REMEMBER_PROMPT } from '../engine/remember'
import { longDate } from '../share/cardLayout'
import { track } from '../analytics/track'

/**
 * Telling us a pet has died, and what is shown afterwards (SPEC-HORIZON §2.5).
 *
 * THE FORM IS AS SHORT AS IT CAN BE. A date, and that is all. No cause, no
 * reflection, no "would you like to tell us more" — anything else is a product
 * asking somebody to do emotional work for its database.
 *
 * IT IS NOT HIDDEN BEHIND A CONFIRMATION MAZE EITHER. Somebody doing this has
 * had a bad enough day. One step back if they mistap, and no "are you sure"
 * dressed up as care.
 */
export function Remembering({
  pet,
  onUpdate,
}: {
  pet: PetProfile
  onUpdate?: (patch: Partial<PetProfile>) => void
}) {
  const remembered = isRemembered(pet)
  const [opening, setOpening] = useState(false)
  const [date, setDate] = useState('')

  if (remembered) {
    return (
      <section className="card overflow-hidden" aria-labelledby="remember-heading">
        <div className="px-5 py-6">
          <h2 id="remember-heading" className="font-display text-[21px] leading-tight text-ink">
            {REMEMBER_HEADLINE(pet.name)}
          </h2>
          <p className="mt-2 text-[14.5px] leading-relaxed text-muted">{REMEMBER_BODY(pet.name)}</p>
          <p className="mt-3 text-[13.5px] text-muted">{REMEMBER_PROMPT}</p>
          {pet.diedOn && (
            <p className="mt-4 text-[13px] text-muted">{longDate(pet.diedOn)}</p>
          )}
          {onUpdate && (
            <button
              type="button"
              onClick={() => onUpdate({ diedOn: undefined })}
              className="mt-4 text-action text-[13px] text-muted"
            >
              Undo — this was a mistake
            </button>
          )}
        </div>
      </section>
    )
  }

  if (!onUpdate) return null

  return (
    <div className="px-5 py-4">
      {opening ? (
        <div>
          <label htmlFor="died-on" className="text-[14px] leading-relaxed text-ink">
            If {pet.name} has died, telling us stops everything — the reminders, the suggestions,
            the questions. Nothing is deleted.
          </label>
          <div className="mt-3 flex flex-wrap items-end gap-2">
            <input
              id="died-on"
              type="date"
              className="field max-w-[190px]"
              max={new Date().toISOString().slice(0, 10)}
              value={date}
              onChange={(e) => setDate(e.target.value)}
            />
            <button
              type="button"
              className="pill-primary px-5 py-2.5 text-[14px]"
              disabled={!date}
              onClick={() => {
                onUpdate({ diedOn: new Date(`${date}T12:00:00Z`).toISOString() })
                track('pet_remembered', { pet_is_demo: !!pet.demo })
                setOpening(false)
              }}
            >
              Save
            </button>
            <button
              type="button"
              className="pill-ghost px-5 py-2.5 text-[14px]"
              onClick={() => setOpening(false)}
            >
              Cancel
            </button>
          </div>
        </div>
      ) : (
        <button
          type="button"
          onClick={() => setOpening(true)}
          className="text-action text-[13px] text-muted"
        >
          {pet.name} has died
        </button>
      )}
    </div>
  )
}
