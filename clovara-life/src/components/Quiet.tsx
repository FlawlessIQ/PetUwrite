import type { PetProfile } from '../data/types'
import { Icon } from './Icon'

/**
 * What a tab says once a pet has died (SPEC-HORIZON §2.5): what it is, one
 * plain sentence, and the way back to the record — which is the one thing that
 * stays. No offer, no question, nothing counted.
 *
 * The engines behind these tabs return nothing for a remembered pet, so this is
 * what renders in place of content rather than a gate in front of it.
 */
export function Quiet({ label, pet, children }: { label: string; pet: PetProfile; children: React.ReactNode }) {
  return (
    <div className="mx-auto w-full max-w-shell px-5 pb-24 pt-8">
      <p className="label">{label}</p>
      <p className="mt-2 max-w-[52ch] text-lead leading-relaxed text-ink-2">{children}</p>
      <a
        href={`#/health/${encodeURIComponent(pet.id)}`}
        className="mt-5 flex max-w-[28rem] items-center justify-between gap-3 rounded-card border border-line bg-white px-5 py-4"
      >
        <span className="text-lead text-ink">{pet.name}&rsquo;s record</span>
        <Icon name="arrow-right" size={18} className="text-ink-2" />
      </a>
    </div>
  )
}
