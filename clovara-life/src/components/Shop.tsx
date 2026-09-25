import { useState } from 'react'
import type { PetProfile, Projection } from '../data/types'
import { recommendProducts } from '../engine/platform'
import { CLAIM_STRENGTH_LABELS, type ClaimStrength } from '../data/products'
import { MemberGate } from './MemberGate'
import { asksFor } from '../data/askRegistry'
import { ContextualAsk } from './ContextualAsk'
import { CloverMark } from './CloverMark'
import { isRemembered } from '../engine/remember'

const STRENGTH_STYLE: Record<ClaimStrength, string> = {
  behaviour: 'bg-sage text-deep',
  supportive: 'bg-accent/12 text-[#8A5510]',
  comfort: 'bg-cream text-ink-2',
}

export function Shop({
  pet,
  projection,
  member,
  busy,
  onStartTrial,
  onUpdate,
}: {
  pet: PetProfile
  projection: Projection
  /** Demo pets are always true — the investor demo must show the whole product. */
  member: boolean
  busy: boolean
  onStartTrial: () => void
  /** Absent for demo pets, which are a fixed exhibit. */
  onUpdate?: (patch: Partial<PetProfile>) => void
}) {
  const [dismissedAsk, setDismissedAsk] = useState(false)
  // SPEC §4.3 places the diet question here rather than in onboarding: it is
  // worth almost nothing to the projection and quite a lot to a shelf of food.
  const dietAsk = onUpdate && !dismissedAsk ? asksFor('shop', pet).find((a) => a.field === 'diet') : undefined
  const [open, setOpen] = useState<string | null>(null)
  const recs = recommendProducts(pet, projection)
  const picked = recs.filter((r) => r.matched.length > 0 || r.stages)
  const staples = recs.filter((r) => !picked.includes(r))

  // Nothing is recommended for a pet who has died (SPEC-HORIZON §2.5).

  if (isRemembered(pet)) {

    return (

      <div className="mx-auto w-full max-w-shell px-5 pb-24 pt-8">

        <p className="label">Shop</p>

        <p className="mt-2 max-w-[52ch] text-[15px] leading-relaxed text-ink-2">

          There is nothing here for {pet.name}. Everything on this shelf was chosen from

          their plan, and we are not going to keep selling to you.

        </p>

      </div>

    )

  }


  return (
    <div className="mx-auto w-full max-w-shell px-5 pb-24 pt-8 sm:pt-10">
      <header className="mb-6">
        <p className="label">Shop</p>
        <h1 className="mt-1.5 font-display text-[34px] leading-[1.1] text-ink sm:text-[40px]">
          Picked for {pet.name}
        </h1>
        <p className="mt-2 max-w-[64ch] text-[15.5px] leading-relaxed text-ink-2">
          {projection.breed.name}, {Math.floor(projection.ageYears)}, {projection.currentStage.label.toLowerCase()}
          {(pet.conditionIds ?? []).length > 0 ? `, managing ${pet.conditionIds.length} condition${pet.conditionIds.length > 1 ? 's' : ''}` : ''}.
          Every card below says why it is here, and it is here because of {pet.name}'s own risk profile —
          not because someone merchandised a shelf.
        </p>
      </header>

      {dietAsk && onUpdate && (
        <ContextualAsk
          ask={dietAsk}
          value={pet.diet}
          onAnswer={(v) => onUpdate({ diet: v })}
          onDismiss={() => setDismissedAsk(true)}
          options={[
            { value: 'measured' as const, label: 'Measured meals' },
            { value: 'free-fed' as const, label: 'Free fed' },
            { value: 'unsure' as const, label: 'Not sure' },
          ]}
        />
      )}

      <section aria-labelledby="picked-heading">
        <h2 id="picked-heading" className="label mb-3">
          Matched to {pet.name}'s profile
        </h2>
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {picked.map((p) => {
            const expanded = open === p.id
            const free = p.price === 0
            return (
              <article key={p.id} className="card flex flex-col overflow-hidden p-0">
                <div className="relative flex h-[112px] items-end justify-center bg-sage/70 pb-3 text-[40px]">
                  <span aria-hidden="true" className="leading-none">{p.emoji}</span>
                  <span className="absolute left-3 right-3 top-3 truncate rounded-full bg-white/92 px-2.5 py-1 text-[11px] font-medium text-deep">
                    {p.why}
                  </span>
                </div>

                <div className="flex flex-1 flex-col p-4">
                  <h3 className="text-[15px] font-medium leading-snug text-ink">{p.name}</h3>
                  <p className="mt-1 text-[13px] leading-snug text-ink-2">{p.subtitle}</p>

                  <div className="mt-3 flex flex-wrap items-center gap-2">
                    <span className={`rounded-full px-2.5 py-0.5 text-[11px] font-medium ${STRENGTH_STYLE[p.claimStrength]}`}>
                      {CLAIM_STRENGTH_LABELS[p.claimStrength].label}
                    </span>
                    {p.subscription && (
                      <span className="rounded-full border border-line px-2.5 py-0.5 text-[11px] text-ink-2">
                        Refill monthly
                      </span>
                    )}
                  </div>

                  <div className="mt-auto pt-4">
                    <div className="flex items-baseline gap-2">
                      {free ? (
                        <span className="font-display text-[19px] font-semibold text-forest">Free</span>
                      ) : (
                        <>
                          <span className="font-display text-[19px] font-semibold text-forest">
                            ${member ? p.memberPrice : p.price}
                          </span>
                          {member ? (
                            <>
                              <span className="text-[13px] text-ink-2 line-through">${p.price}</span>
                              <span className="text-[12px] text-ink-2">member</span>
                            </>
                          ) : (
                            <span className="text-[12px] text-ink-2">
                              ${p.memberPrice} for members
                            </span>
                          )}
                        </>
                      )}
                    </div>
                    <p className="mt-0.5 text-[12px] text-ink-2">Earns {p.points} points</p>

                    <button
                      type="button"
                      onClick={() => setOpen(expanded ? null : p.id)}
                      aria-expanded={expanded}
                      className="mt-3 text-[13px] text-forest hover:text-deep text-action"
                    >
                      {expanded ? 'Hide the evidence' : 'What the evidence says'}
                    </button>
                    {expanded && (
                      <p className="reveal mt-2 rounded-soft bg-cream/70 p-3 text-[13px] leading-relaxed text-ink/80">
                        {p.evidenceNote}
                      </p>
                    )}
                  </div>
                </div>
              </article>
            )
          })}
        </div>
      </section>

      {staples.length > 0 && (
        <section className="mt-10" aria-labelledby="staples-heading">
          <h2 id="staples-heading" className="label mb-3">
            Everything else
          </h2>
          <ul className="card divide-y divide-line p-0">
            {staples.map((p) => (
              <li key={p.id} className="flex items-center gap-4 px-5 py-3.5">
                <span aria-hidden="true" className="grid h-11 w-11 shrink-0 place-items-center rounded-soft bg-cream text-[20px]">
                  {p.emoji}
                </span>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-[14.5px] font-medium text-ink">{p.name}</p>
                  <p className="truncate text-[12.5px] text-ink-2">{p.subtitle}</p>
                </div>
                <span className="shrink-0 text-[14px] font-medium text-forest">
                  {p.price === 0 ? 'Free' : `$${member ? p.memberPrice : p.price}`}
                </span>
              </li>
            ))}
          </ul>
        </section>
      )}

      {!member && (
        <div className="mt-6">
          <MemberGate
            reason={`You're seeing list prices. Members pay less on every order and earn points back on the products that keep ${pet.name} healthy.`}
            busy={busy}
            onStart={onStartTrial}
          />
        </div>
      )}

      <section className="card mt-6 flex flex-wrap items-center gap-4 bg-sage/60 px-5 py-4">
        <CloverMark size={26} />
        <p className="min-w-[12rem] flex-1 text-[14px] leading-relaxed text-deep">
          Total Care members save on every order and earn points back on the products that keep
          {' '}{pet.name} healthy. Membership is priced separately from insurance.
        </p>
      </section>

      <p className="mt-5 text-[13px] leading-relaxed text-ink-2">
        Product names, prices and images in this preview are illustrative placeholders. The matching
        logic is not — each item is here because it targets a condition on {pet.name}'s own risk
        cards. Supplement copy is deliberately qualitative: nothing here claims to treat or prevent
        a condition.
      </p>
    </div>
  )
}
