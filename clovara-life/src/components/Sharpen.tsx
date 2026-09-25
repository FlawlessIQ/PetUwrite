import { useMemo, useState } from 'react'
import { track } from '../analytics/track'
import type {
  ActivityLevel,
  BodyConditionScore,
  DentalRoutine,
  NeuterAgeBand,
  OutdoorAccess,
  PetProfile,
} from '../data/types'
import { JOINT_RISK_WEIGHT_LB, NEUTER_AGE_LABELS, conditionsFor, findBreed } from '../data/engine'
import { planAccuracy } from '../engine/accuracy'
import { BCS_LABELS, Silhouette } from './Silhouette'
import { PhotoPicker } from './PhotoPicker'

/**
 * Tier 1 — sharpening, after the reveal (SPEC §4.2).
 *
 * Everything here is optional and inline. Nothing is a wall, nothing is a form,
 * and the order is the accuracy meter's order — most valuable question first —
 * so the fastest route through is also the one that sharpens the plan most.
 *
 * THE INCENTIVE MECHANIC IS THE POINT. SPEC: "Each answer visibly moves the
 * projection — build it as such." So every control writes straight through to
 * the stored profile, the projection recomputes, and the number above animates.
 * There is no save button: a save button would make this a form again.
 *
 * Answered questions tidy away on the NEXT visit, not the moment they are
 * answered — collapsing instantly means a mis-tapped silhouette cannot be
 * corrected without hunting for it, and hides the confirmation exactly when
 * someone wants to see it. "Change something you already answered" brings them
 * all back.
 */
export function Sharpen({
  pet,
  householdId,
  onUpdate,
  revisitField = null,
}: {
  pet: PetProfile
  householdId: string | null
  onUpdate: (patch: Partial<PetProfile>) => void
  /**
   * A field the annual review sent someone here to change. It is shown even
   * though it is already answered — otherwise "this changed" would scroll to
   * a question that is not on the page.
   */
  revisitField?: string | null
}) {
  const [showAnswered, setShowAnswered] = useState(false)
  /**
   * Fields answered in this visit stay on screen.
   *
   * Collapsing a question the instant it is answered means a mis-tapped
   * silhouette cannot be corrected without hunting for it, and it hides the
   * confirmation at the exact moment someone wants to see it. Tidying away is
   * for the next visit, not this one.
   */
  const [justAnswered, setJustAnswered] = useState<Set<string>>(() => new Set())
  const answer = (field: string, patch: Partial<PetProfile>) => {
    setJustAnswered((prev) => new Set(prev).add(field))
    // Every Tier-1 answer goes through here, which is why the event does too:
    // a second emission site is how a funnel quietly stops counting something.
    track('tier1_field_added', { field, pet_is_demo: !!pet.demo, species: pet.species })
    onUpdate(patch)
  }
  const breed = findBreed(pet.breedId)
  const accuracy = planAccuracy(pet)

  const conditions = useMemo(() => conditionsFor(pet.species), [pet.species])
  const asksNeuterAge =
    pet.species === 'dog' &&
    pet.neutered === true &&
    !!breed &&
    (breed.weight.low + breed.weight.high) / 2 >= JOINT_RISK_WEIGHT_LB

  if (!breed) return null

  /** A question, rendered only when it is unanswered or the owner asked to see it. */
  const Question = ({
    field,
    title,
    children,
  }: {
    field: string
    title: string
    children: React.ReactNode
  }) => {
    const meta = accuracy.fields.find((f) => f.field === field)
    if (!meta) return null
    if (meta.answered && !showAnswered && !justAnswered.has(field) && field !== revisitField)
      return null
    return (
      <div className="border-t border-line px-5 py-5 first:border-t-0 sm:px-6">
        <div className="mb-1 flex flex-wrap items-center justify-between gap-x-3 gap-y-1">
          <h3 className="text-[15.5px] font-medium text-ink">{title}</h3>
          {meta.answered ? (
            <span className="rounded-full bg-sage px-2.5 py-0.5 text-[11px] font-medium text-deep">
              Answered
            </span>
          ) : (
            <span className="text-[12.5px] text-ink-2">+{meta.points} to sharpness</span>
          )}
        </div>
        <p className="mb-3.5 text-[13.5px] leading-snug text-ink-2">{meta.benefit}</p>
        {children}
      </div>
    )
  }

  const Choice = <T extends string | number | boolean>({
    options,
    value,
    onPick,
    label,
  }: {
    options: { value: T; label: string; hint?: string }[]
    value: T | undefined
    onPick: (v: T) => void
    label: string
  }) => (
    <div role="radiogroup" aria-label={label} className="grid gap-2 sm:grid-cols-3">
      {options.map((o) => {
        const on = value === o.value
        return (
          <button
            key={String(o.value)}
            type="button"
            role="radio"
            aria-checked={on}
            onClick={() => onPick(o.value)}
            className={`rounded-soft border px-3 py-2.5 text-left transition ${
              on
                ? 'border-forest bg-forest text-white shadow-soft'
                : 'border-line bg-white text-ink hover:border-forest/50'
            }`}
          >
            <span className="block text-[14.5px] font-medium leading-tight">{o.label}</span>
            {o.hint && (
              <span className={`mt-0.5 block text-[12px] ${on ? 'text-white/70' : 'text-ink-2'}`}>
                {o.hint}
              </span>
            )}
          </button>
        )
      })}
    </div>
  )

  const unanswered = accuracy.fields.filter((f) => !f.answered).length

  return (
    <section className="card overflow-hidden" aria-labelledby="sharpen-heading">
      <div className="border-b border-line bg-cream/50 px-5 py-4 sm:px-6">
        <h2 id="sharpen-heading" className="font-display text-[22px] leading-tight text-ink">
          {unanswered === 0 ? `${pet.name}'s plan is as sharp as we can make it` : 'Sharpen the plan'}
        </h2>
        <p className="mt-1 text-[14px] leading-snug text-ink-2">
          {unanswered === 0
            ? "You've told us everything that moves the number. Change any of it any time."
            : `${unanswered} question${unanswered === 1 ? '' : 's'} left, each one optional. Watch the range above as you answer.`}
        </p>
      </div>

      {/* ── Body condition — silhouettes, never kg first (SPEC §4.2) ──── */}
      <Question field="weightLb" title={`What shape is ${pet.name} in?`}>
        <div className="grid grid-cols-5 gap-1 sm:gap-2">
          {([1, 2, 3, 4, 5] as BodyConditionScore[]).map((score) => {
            const on = pet.bodyConditionScore === score
            return (
              <button
                key={score}
                type="button"
                aria-pressed={on}
                aria-label={`${BCS_LABELS[score].label} — ${BCS_LABELS[score].detail}`}
                onClick={() => answer('weightLb', { bodyConditionScore: score })}
                className={`rounded-soft border p-1 transition sm:p-2 ${
                  on ? 'border-forest bg-sage shadow-soft' : 'border-line bg-white hover:border-forest/50'
                }`}
              >
                <span className="mx-auto block h-[58px] w-full max-w-[44px] sm:h-[68px]">
                  <Silhouette score={score} species={pet.species} active={on} />
                </span>
                <span
                  className={`mt-1 block whitespace-nowrap text-center text-[9.5px] leading-tight sm:text-[11.5px] ${
                    on ? 'font-medium text-deep' : 'text-ink-2'
                  }`}
                >
                  {BCS_LABELS[score].label}
                </span>
              </button>
            )
          })}
        </div>
        {pet.bodyConditionScore && (
          <p className="mt-2.5 text-[13.5px] leading-relaxed text-ink-2">
            {BCS_LABELS[pet.bodyConditionScore].detail}.{' '}
            <span className="text-ink/70">
              A weight in pounds is optional and does not change this — you have already told us the
              thing that matters.
            </span>
          </p>
        )}
        <div className="mt-3">
          <label htmlFor="sharpen-weight" className="label mb-1.5 block">
            Weight in pounds (optional)
          </label>
          <input
            id="sharpen-weight"
            type="number"
            inputMode="decimal"
            min={1}
            max={400}
            className="field max-w-[12rem]"
            defaultValue={pet.weightLb > 0 ? pet.weightLb : ''}
            placeholder={String(Math.round((breed.weight.low + breed.weight.high) / 2))}
            onBlur={(e) => {
              const n = Number(e.target.value)
              if (Number.isFinite(n) && n > 0 && n !== pet.weightLb) answer('weightLb', { weightLb: n })
            }}
          />
          <p className="mt-1.5 text-[12.5px] text-ink-2">
            Typical adult range for a {breed.name}: {breed.weight.low}–{breed.weight.high} lb.
          </p>
        </div>
      </Question>

      {/* ── Conditions ─────────────────────────────────────────────────── */}
      <Question field="conditionIds" title="Anything already diagnosed?">
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            aria-pressed={pet.conditionsReviewed === true && pet.conditionIds.length === 0}
            onClick={() => answer('conditionIds', { conditionIds: [], conditionsReviewed: true })}
            className={`rounded-full border px-3.5 py-1.5 text-[14px] transition ${
              pet.conditionsReviewed && pet.conditionIds.length === 0
                ? 'border-forest bg-forest text-white'
                : 'border-line bg-white text-ink hover:border-forest/50'
            }`}
          >
            None that I know of
          </button>
          {conditions.map((c) => {
            const on = pet.conditionIds.includes(c.id)
            return (
              <button
                key={c.id}
                type="button"
                aria-pressed={on}
                onClick={() =>
                  answer('conditionIds', {
                    conditionIds: on
                      ? pet.conditionIds.filter((x) => x !== c.id)
                      : [...pet.conditionIds, c.id],
                    conditionsReviewed: true,
                  })
                }
                className={`rounded-full border px-3.5 py-1.5 text-[14px] transition ${
                  on
                    ? 'border-forest bg-forest text-white'
                    : 'border-line bg-white text-ink hover:border-forest/50'
                }`}
              >
                {c.name}
              </button>
            )
          })}
        </div>
      </Question>

      {/* ── Neutered ───────────────────────────────────────────────────── */}
      <Question field="neutered" title="Neutered or spayed?">
        <Choice
          label="Neutered"
          value={pet.neutered}
          onPick={(v: boolean) => answer('neutered', { neutered: v })}
          options={[
            { value: true, label: 'Yes' },
            { value: false, label: 'No' },
          ]}
        />
      </Question>

      {asksNeuterAge && (
        <Question field="neuterAgeBand" title="Roughly how old were they then?">
          <Choice
            label="Age at neutering"
            value={pet.neuterAgeBand}
            onPick={(v: NeuterAgeBand) => answer('neuterAgeBand', { neuterAgeBand: v })}
            options={NEUTER_AGE_LABELS}
          />
        </Question>
      )}

      {/* ── Cats: outdoor access ───────────────────────────────────────── */}
      {pet.species === 'cat' && (
        <Question field="outdoorAccess" title={`How much of the world does ${pet.name} get?`}>
          <Choice
            label="Outdoor access"
            value={pet.outdoorAccess}
            onPick={(v: OutdoorAccess) => answer('outdoorAccess', { outdoorAccess: v })}
            options={[
              { value: 'indoor', label: 'Indoor', hint: 'Never out alone' },
              { value: 'indoor-outdoor', label: 'Both', hint: 'Comes and goes' },
              { value: 'outdoor', label: 'Outdoor', hint: 'Mostly outside' },
            ]}
          />
        </Question>
      )}

      {/* ── Lifestyle ──────────────────────────────────────────────────── */}
      <Question field="activity" title="How much do they move on a normal day?">
        <Choice
          label="Activity"
          value={pet.activity}
          onPick={(v: ActivityLevel) => answer('activity', { activity: v })}
          options={[
            { value: 'low', label: 'Low', hint: 'Short or irregular' },
            { value: 'moderate', label: 'Moderate', hint: 'Daily, steady' },
            { value: 'high', label: 'High', hint: 'Long and varied' },
          ]}
        />
      </Question>

      <Question field="dental" title="Teeth cleaned at home?">
        <Choice
          label="Dental routine"
          value={pet.dental}
          onPick={(v: DentalRoutine) => answer('dental', { dental: v })}
          options={[
            { value: 'daily', label: 'Daily' },
            { value: 'weekly', label: 'Weekly' },
            { value: 'rarely', label: 'Rarely' },
          ]}
        />
      </Question>


      <PhotoPicker pet={pet} householdId={householdId} onUpdate={onUpdate} />

      <div className="border-t border-line bg-cream/50 px-5 py-3.5 sm:px-6">
        <button
          type="button"
          onClick={() => setShowAnswered((v) => !v)}
          className="text-[13.5px] text-forest hover:text-deep text-action"
        >
          {showAnswered ? 'Hide what you have answered' : 'Change something you already answered'}
        </button>
      </div>
    </section>
  )
}
