import type { PetProfile, Projection } from '../data/types'
import { MemberGate } from './MemberGate'
import { buildRewards } from '../engine/platform'
import { REWARDS_DISCLAIMER } from '../data/rewards'
import { Quiet } from './Quiet'

export function Rewards({
  pet,
  projection,
  member,
  busy,
  onStartTrial,
}: {
  pet: PetProfile
  projection: Projection
  /** Demo pets are always true — the investor demo must show the whole product. */
  member: boolean
  busy: boolean
  onStartTrial: () => void
}) {
  const r = buildRewards(pet, projection)
  // Null once a pet has died: nothing is counted, nothing is redeemable.
  if (!r) {
    return (
      <Quiet label="Rewards" pet={pet}>
        Nothing is being counted for {pet.name} any more.
      </Quiet>
    )
  }

  return (
    <div className="mx-auto w-full max-w-shell px-5 pb-24 pt-8 sm:pt-10">
      <header className="mb-6">
        <p className="label">Rewards</p>
        <h1 className="mt-1.5 font-display text-display-lg leading-[1.1] text-ink sm:text-display-xl">
          Healthy habits, rewarded
        </h1>
        <p className="mt-2 max-w-[62ch] text-lead leading-relaxed text-ink-2">
          The behaviours that earn the most points are the same ones that move {pet.name}'s
          healthy-years projection. That alignment is the design — points follow evidence, not
          engagement for its own sake.
        </p>
      </header>

      <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)] lg:items-start">
        <div className="space-y-5">
          <section className="card relative overflow-hidden bg-deep p-0 text-white">
            <div
              aria-hidden="true"
              className="pointer-events-none absolute -right-16 -top-16 h-56 w-56 rounded-full"
              style={{ background: 'radial-gradient(circle, rgba(217,138,38,.38), transparent 70%)' }}
            />
            <div className="relative px-6 py-6">
              <p className="text-caption font-semibold uppercase tracking-[0.18em] text-white/70">
                Clovara points
              </p>
              <p className="mt-1.5 font-display text-display-2xl font-semibold leading-none">
                {r.points.toLocaleString()}
              </p>
              <p className="mt-2 text-body text-white/75">
                +{r.weekPoints} this week, from care streaks and activity
              </p>

              <div className="mt-5 grid grid-cols-3 gap-2.5">
                {r.streaks.map((s) => (
                  <div key={s.label} className="rounded-soft bg-white/10 px-3 py-3 text-center">
                    <p className="font-display text-heading-lg font-semibold leading-none">{s.value}</p>
                    <p className="mt-1.5 text-caption font-medium leading-tight text-white/90">
                      {s.label}
                    </p>
                    <p className="mt-0.5 text-caption leading-tight text-white/60">{s.note}</p>
                  </div>
                ))}
              </div>
            </div>
          </section>

          <section className="card overflow-hidden" aria-labelledby="earn-heading">
            <div className="border-b border-line bg-cream/50 px-5 py-4 sm:px-6">
              <h2 id="earn-heading" className="font-display text-heading-lg leading-tight text-ink">
                How points are earned
              </h2>
              <p className="mt-1 text-body-lg leading-snug text-ink-2">
                {r.alignedCount} of these also move the healthy-years number. Those are marked.
              </p>
            </div>
            <ul className="divide-y divide-line">
              {r.rules
                .filter((rule) => rule.points > 0)
                .map((rule) => (
                  <li key={rule.id} className="flex items-center gap-3 px-5 py-3.5 sm:px-6">
                    <div className="min-w-0 flex-1">
                      <p className="text-body-lg font-medium text-ink">{rule.label}</p>
                      <p className="mt-0.5 text-body-sm capitalize text-ink-2">{rule.cadence}</p>
                    </div>
                    {rule.movesProjection && (
                      <span className="chip-good shrink-0">
                        Moves the projection
                      </span>
                    )}
                    <span className="shrink-0 font-display text-lead font-semibold text-forest">
                      +{rule.points}
                    </span>
                  </li>
                ))}
            </ul>
          </section>
        </div>

        <section className="card overflow-hidden" aria-labelledby="redeem-heading">
          <div className="border-b border-line bg-cream/50 px-5 py-4 sm:px-6">
            <h2 id="redeem-heading" className="font-display text-heading-lg leading-tight text-ink">
              Redeem points
            </h2>
            <p className="mt-1 text-body-lg leading-snug text-ink-2">
              Products and care services. Never premium — that is a regulatory line, not a product
              choice.
            </p>
          </div>

          {!member && (
            <div className="border-b border-line px-5 py-4 sm:px-6">
              <MemberGate
                reason={`Redeeming points is part of membership. ${pet.name}'s points keep adding up either way — nothing expires while you decide.`}
                busy={busy}
                onStart={onStartTrial}
              />
            </div>
          )}

          <ul className="divide-y divide-line">
            {r.redemptions.map((item) => (
              <li key={item.id} className="flex items-center gap-3.5 px-5 py-4 sm:px-6">
                <span
                  aria-hidden="true"
                  className="grid h-11 w-11 shrink-0 place-items-center rounded-soft bg-sage text-heading-sm"
                >
                  {item.emoji}
                </span>
                <div className="min-w-0 flex-1">
                  <p className="text-body-lg font-medium leading-snug text-ink">{item.label}</p>
                  <p className="mt-0.5 text-body-sm leading-snug text-ink-2">{item.detail}</p>
                  {item.recommended && (
                    <p className="mt-1 text-caption font-semibold uppercase tracking-[0.18em] text-amber">
                      Suggested for {pet.name}
                    </p>
                  )}
                </div>
                <div className="shrink-0 text-right">
                  <p className="font-display text-lead font-semibold text-forest">
                    {item.cost.toLocaleString()}
                  </p>
                  <p className="text-caption text-ink-2">points</p>
                  {!item.affordable && (
                    <p className="mt-0.5 text-caption text-ink-2">
                      {(item.cost - r.points).toLocaleString()} to go
                    </p>
                  )}
                </div>
              </li>
            ))}
          </ul>
        </section>
      </div>

      <p className="mt-6 text-body-sm leading-relaxed text-ink-2">{REWARDS_DISCLAIMER}</p>
    </div>
  )
}
