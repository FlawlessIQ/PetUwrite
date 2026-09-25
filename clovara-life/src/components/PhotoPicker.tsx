import { useRef, useState } from 'react'
import type { PetProfile } from '../data/types'
import { describeRejection } from '../store/imageMath'
import { PetAvatar } from './PetAvatar'

/**
 * Add a photo (SPEC §4.2).
 *
 * `capture="environment"` so a phone offers the camera first — most people
 * adding a photo of the animal in front of them want to take one, not go
 * hunting in a library.
 *
 * Worth no accuracy points, and the copy says so rather than implying the plan
 * improves. It is here because it makes the app theirs, which is reason enough.
 */
export function PhotoPicker({
  pet,
  householdId,
  onUpdate,
}: {
  pet: PetProfile
  /** Null when signed out — photos need somewhere to live. */
  householdId: string | null
  onUpdate: (patch: Partial<PetProfile>) => void
}) {
  const input = useRef<HTMLInputElement>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const pick = async (file: File | undefined) => {
    if (!file) return
    const rejection = describeRejection(file)
    if (rejection) {
      setError(rejection)
      return
    }
    if (!householdId) {
      setError('Sign in first and their photo will follow them to every device.')
      return
    }
    setBusy(true)
    setError(null)
    try {
      const { uploadPetPhoto } = await import('../store/photos')
      const photo = await uploadPetPhoto(file, { householdId, petId: pet.id })
      onUpdate({ photo })
    } catch (err) {
      setError(
        (err as Error)?.message ||
          "That photo didn't upload. Try again, or a different one.",
      )
    } finally {
      setBusy(false)
      if (input.current) input.current.value = ''
    }
  }

  return (
    <div className="border-t border-line px-5 py-5 sm:px-6" data-ask="photo">
      <div className="mb-1 flex flex-wrap items-center justify-between gap-x-3 gap-y-1">
        <h3 className="text-[15.5px] font-medium text-ink">
          {pet.photo ? `A photo of ${pet.name}` : `Add a photo of ${pet.name}`}
        </h3>
        <span className="text-[12.5px] text-ink-2">Changes nothing in the plan</span>
      </div>
      <p className="mb-3.5 text-[13.5px] leading-snug text-ink-2">
        It makes the app theirs, and we keep a larger copy so their shape can be
        compared over time later on.
      </p>

      <div className="flex flex-wrap items-center gap-4">
        <PetAvatar pet={pet} size={64} />
        <div>
          <button
            type="button"
            onClick={() => input.current?.click()}
            disabled={busy}
            className="pill-ghost pill-sm disabled:opacity-50"
          >
            {busy ? 'Uploading…' : pet.photo ? 'Replace photo' : 'Add a photo'}
          </button>
          <input
            ref={input}
            type="file"
            // Named for a screen reader: the visible control is the button
            // that clicks this, and without a name this announces as "file".
            aria-label={`Add a photo of ${pet.name}`}
            accept="image/jpeg,image/png,image/webp,image/heic,image/heif"
            capture="environment"
            className="sr-only"
            onChange={(e) => void pick(e.target.files?.[0])}
          />
        </div>
      </div>

      {error && (
        <p role="alert" className="mt-3 text-[13.5px] leading-relaxed text-[#8A5510]">
          {error}
        </p>
      )}
    </div>
  )
}
