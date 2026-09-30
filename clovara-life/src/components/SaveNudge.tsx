import { useEffect, useState } from 'react'
import type { PetProfile } from '../data/types'
import { shouldAskToSave, worthKeeping, type SavePromptMemory } from '../engine/savePrompt'
import { track } from '../analytics/track'

/**
 * "Keep Bruno's plan" (ACQUISITION-ONBOARDING-PLAN, AO2).
 *
 * The biggest leak in the funnel was silence: a pet made signed-out lives only
 * in that browser and nothing said so. This says so, once after the reveal and
 * at most once more — see engine/savePrompt.ts for when. Never a modal, never
 * over the reveal, and "Not now" is always there.
 */
const KEY = 'clovara-life.save-prompt.v1'

function readMemory(petId: string): SavePromptMemory | null {
  try {
    const all = JSON.parse(localStorage.getItem(KEY) ?? '{}') as Record<string, SavePromptMemory>
    return all[petId] ?? null
  } catch {
    return null
  }
}

function writeMemory(petId: string, m: SavePromptMemory): void {
  try {
    const all = JSON.parse(localStorage.getItem(KEY) ?? '{}') as Record<string, SavePromptMemory>
    all[petId] = m
    localStorage.setItem(KEY, JSON.stringify(all))
  } catch {
    /* Blocked storage: it may ask again next visit. Better than never asking. */
  }
}

export function SaveNudge({
  pet,
  onKeep,
  surface,
}: {
  pet: PetProfile
  /** Opens sign-in. Absent when there is nothing to ask — signed in, or a demo pet. */
  onKeep?: () => void
  surface: 'life' | 'home'
}) {
  const [memory, setMemory] = useState(() => readMemory(pet.id))
  const show = !!onKeep && shouldAskToSave(pet, { signedIn: false, memory })

  useEffect(() => {
    if (show) track('save_prompt', { action: 'viewed', surface, nth: (memory?.dismissals ?? 0) + 1 })
    // Once per appearance, not per render: keyed on whether it shows, for which pet.
  }, [show, pet.id])

  if (!show) return null

  const dismiss = () => {
    const next = { dismissals: (memory?.dismissals ?? 0) + 1, keptAtDismissal: worthKeeping(pet) }
    writeMemory(pet.id, next)
    setMemory(next)
    track('save_prompt', { action: 'dismissed', surface, nth: next.dismissals })
  }

  return (
    // No heading: the button says "Keep Bruno's plan", and a heading saying it
    // too cost the line that kept a puppy's first-hours page inside its budget.
    <section
      id={`save-${surface}`}
      className="card border-forest/25 bg-sage/30 px-5 py-4 sm:px-6"
      aria-label={`Keep ${pet.name}'s plan`}
    >
      <p className="text-body leading-relaxed text-ink sm:text-body-lg">
        {pet.name}&rsquo;s plan lives only in this browser until you save it. Saved, it&rsquo;s on
        your phone too. No card needed.
      </p>
      <div className="mt-2.5 flex flex-wrap items-center gap-3">
        {/* Compact: it sits in the longest page there is, a puppy's first
            hours, which verify-length holds to twelve screens. */}
        <button
          type="button"
          className="pill-primary pill-sm"
          onClick={() => {
            track('save_prompt', { action: 'accepted', surface, nth: (memory?.dismissals ?? 0) + 1 })
            onKeep?.()
          }}
        >
          Keep {pet.name}&rsquo;s plan
        </button>
        <button type="button" className="text-body text-forest text-action" onClick={dismiss}>
          Not now
        </button>
      </div>
    </section>
  )
}
