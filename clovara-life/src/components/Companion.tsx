import type { PetProfile, Projection } from '../data/types'
import { useMemo } from 'react'
import { scriptedTurns } from '../companion/script'
import { buildCompanion } from '../engine/platform'
import { AskCompanion } from './AskCompanion'
import { ScriptedConversation } from './companion/Conversation'
import { isRemembered } from '../engine/remember'
import { Quiet } from './Quiet'

export function Companion({ pet, projection }: { pet: PetProfile; projection: Projection }) {
  const turns = useMemo(() => scriptedTurns(buildCompanion(pet, projection)), [pet, projection])
  const knownSince = new Date(pet.birthDate).getFullYear()

  // The thread is empty for a remembered pet (buildCompanion). The Ask box
  // goes too: "What would you like to know about {name}?" is a question about
  // how they are doing, and the Remember pass promises those have stopped.
  if (isRemembered(pet)) {
    return (
      <Quiet label="Companion" pet={pet}>
        The companion has stopped. Everything it knew about {pet.name} is in their record, and the
        one-page summary is still there if a vet ever asks for it.
      </Quiet>
    )
  }

  return (
    <div className="mx-auto w-full max-w-[760px] px-5 pb-24 pt-8 sm:pt-10">
      <header className="mb-6">
        <p className="label">Companion</p>
        <h1 className="mt-1.5 font-display text-display-lg leading-[1.1] text-ink sm:text-display-xl">
          It remembers {pet.name}
        </h1>
        <p className="mt-2 max-w-[62ch] text-lead leading-relaxed text-ink-2">
          Knows {pet.name} since {knownSince}. This conversation is built from {pet.name}'s own
          record — the condition on file, the risk window {pet.sex === 'female' ? 'she' : 'he'} is in
          right now, and the signs that actually matter for a {projection.breed.name}. Switch pets
          and it changes, because the memory changes.
        </p>
      </header>

      <AskCompanion pet={pet} projection={projection} />


      <div className="card mt-5 px-4 py-5 sm:px-6 sm:py-6">
        {/* DESIGN.md §5b: typed blocks through the kit, never free text. */}
        <ScriptedConversation key={pet.id} turns={turns} petName={pet.name} since={knownSince} />
      </div>

      <div className="mt-5 grid gap-3 sm:grid-cols-2">
        <p className="rounded-soft border border-line bg-white px-4 py-3.5 text-body leading-relaxed text-ink-2">
          The companion shares information and routes you to a licensed vet. It does not diagnose —
          that is the legal line and the trust line, and they happen to be the same line.
        </p>
        <p className="rounded-soft border border-line bg-white px-4 py-3.5 text-body leading-relaxed text-ink-2">
          Conversations here are firewalled from underwriting and claims. What you tell the
          assistant does not price your policy.
        </p>
      </div>

      <p className="mt-4 text-body-sm leading-relaxed text-ink-2">
        This thread is scripted for the preview, but every specific in it is pulled from {pet.name}'s
        record rather than written by hand.
      </p>
    </div>
  )
}
