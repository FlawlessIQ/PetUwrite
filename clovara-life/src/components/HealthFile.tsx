import type { PetProfile, Projection } from '../data/types'
import { Vaccines } from './Vaccines'
import { VisitSummary } from './VisitSummary'
import { LumpDiary } from './LumpDiary'
import { Remembering } from './Remembering'
import { Meds } from './Meds'
import { SecondOpinion } from './SecondOpinion'
import { SeniorSuite } from './SeniorSuite'
import { isRemembered } from '../engine/remember'
import { Passport } from './Passport'
import { SitterMode } from './SitterMode'
import { ConfirmChips } from './ConfirmChips'
import { passportState } from '../engine/passport'
import { vaccineState } from '../engine/vaccines'

/**
 * The Health File (SPEC §4.3: "show provenance in the pet's Health File").
 *
 * WHY THIS EXISTS AT ALL. Every P3 surface was built onto the Life page, one at
 * a time, each verified alone. Together they made the Life surface fifteen
 * phone screens for a new puppy — so somebody reached the reveal in under sixty
 * seconds and then hit a wall. Nothing on this page is time-sensitive: a
 * vaccination record, a socialisation checklist and a sitter link are all
 * things you go and look at, not things that should meet you.
 *
 * What stays on Life is the projection, the sharpening that moves it, and the
 * things that are only true for a few days.
 */
export function HealthFile({
  pet,
  projection,
  householdId,
  signedIn,
  onUpdate,
  onClose,
  now = new Date(),
}: {
  pet: PetProfile
  projection: Projection
  householdId: string | null
  signedIn: boolean
  onUpdate?: (patch: Partial<PetProfile>) => void
  onClose: () => void
  now?: Date
}) {
  const vax = vaccineState(pet, now)
  const passport = passportState(pet, now)

  return (
    <div className="mx-auto w-full max-w-shell px-5 pb-24 pt-6">
      <div className="mb-5 flex flex-wrap items-start justify-between gap-3">
        <div>
          <p className="label">Health file</p>
          <h1 className="mt-1 font-display text-[28px] leading-tight text-ink">
            Everything on record for {pet.name}
          </h1>
          <p className="mt-1.5 max-w-[56ch] text-[14px] leading-relaxed text-ink-2">
            The things you keep rather than the things that need you today. Nothing here is shared
            with anyone unless you make a sitter link.
          </p>
        </div>
        <button type="button" onClick={onClose} className="pill-ghost px-4 py-2 text-[13.5px]">
          Back to {pet.name}
        </button>
      </div>

      <div className="grid gap-5 lg:grid-cols-2 lg:items-start">
        <div className="space-y-5">
          <VisitSummary pet={pet} projection={projection} now={now} />
          {!isRemembered(pet) && <Meds pet={pet} onUpdate={onUpdate} now={now} />}
          {!isRemembered(pet) && <SecondOpinion pet={pet} projection={projection} />}
          {vax.visible && <Vaccines pet={pet} onUpdate={onUpdate} now={now} />}
          <ConfirmChips candidates={[]} onConfirmed={() => {}} />
        </div>
        <div className="space-y-5">
          <SeniorSuite pet={pet} projection={projection} />
          <LumpDiary pet={pet} householdId={householdId} onUpdate={onUpdate} now={now} />
          {passport.visible && <Passport pet={pet} onUpdate={onUpdate} now={now} />}
          {onUpdate && !isRemembered(pet) && (
            <SitterMode pet={pet} signedIn={signedIn} onUpdate={onUpdate} />
          )}
        </div>
      </div>

      {!vax.visible && !passport.visible && (
        <p className="mt-2 text-[14px] leading-relaxed text-ink-2">
          {pet.name} is past the age for the vaccination course and the socialisation passport, so
          there is nothing to show from either.
        </p>
      )}

      <div className="mt-6 border-t border-line pt-2">
        <Remembering pet={pet} onUpdate={onUpdate} />
      </div>

      <p className="mt-4 text-[12.5px] leading-relaxed text-ink-2">
        Reading vet records into this file is built and switched off — it needs a security review of
        how those documents are stored before it can be turned on. The projection on {pet.name}
        &rsquo;s plan does not use anything from this page.
      </p>
    </div>
  )
}
