import { useMemo, useState } from 'react'
import type {
  ActivityLevel,
  Breed,
  DentalRoutine,
  DietQuality,
  PetProfile,
  Sex,
  SizeClass,
  Species,
} from '../data/types'
import { MIXED_BY_SIZE, SIZE_LABELS, breedsFor, conditionsFor, findBreed } from '../data/engine'
import { readBodyCondition } from '../engine/project'
import { CloverMark } from './CloverMark'

const STEPS = ['Pet', 'Breed', 'Birthday', 'Weight', 'History', 'Lifestyle'] as const

interface Props {
  onComplete: (pet: PetProfile) => void
  onCancel?: () => void
}

function Segmented<T extends string>({
  options,
  value,
  onChange,
  name,
}: {
  options: { value: T; label: string; hint?: string }[]
  value: T | null
  onChange: (v: T) => void
  name: string
}) {
  return (
    <div role="radiogroup" aria-label={name} className="grid gap-2.5 sm:grid-cols-3">
      {options.map((o) => {
        const active = value === o.value
        return (
          <button
            key={o.value}
            type="button"
            role="radio"
            aria-checked={active}
            onClick={() => onChange(o.value)}
            className={`rounded-soft border px-4 py-3 text-left transition ${
              active
                ? 'border-forest bg-forest text-white shadow-soft'
                : 'border-line bg-white text-ink hover:border-forest/50'
            }`}
          >
            <span className="block text-[15px] font-medium leading-tight">{o.label}</span>
            {o.hint && (
              <span className={`mt-0.5 block text-[12.5px] leading-snug ${active ? 'text-white/70' : 'text-muted'}`}>
                {o.hint}
              </span>
            )}
          </button>
        )
      })}
    </div>
  )
}

export function Onboarding({ onComplete, onCancel }: Props) {
  const [step, setStep] = useState(0)
  const [name, setName] = useState('')
  const [species, setSpecies] = useState<Species | null>(null)
  const [breedId, setBreedId] = useState<string | null>(null)
  const [breedQuery, setBreedQuery] = useState('')
  const [mixedSize, setMixedSize] = useState<SizeClass | null>(null)
  const [showSizePicker, setShowSizePicker] = useState(false)
  const [birthDate, setBirthDate] = useState('')
  const [sex, setSex] = useState<Sex | null>(null)
  const [neutered, setNeutered] = useState<boolean | null>(null)
  const [weightLb, setWeightLb] = useState('')
  const [conditionIds, setConditionIds] = useState<string[]>([])
  const [conditionQuery, setConditionQuery] = useState('')
  const [activity, setActivity] = useState<ActivityLevel>('moderate')
  const [dental, setDental] = useState<DentalRoutine>('weekly')
  const [diet, setDiet] = useState<DietQuality>('measured')

  const breed: Breed | undefined = breedId ? findBreed(breedId) : undefined

  const breedMatches = useMemo(() => {
    if (!species) return []
    const all = breedsFor(species).filter((b) => !b.id.startsWith('mixed-'))
    const q = breedQuery.trim().toLowerCase()
    if (!q) return all.slice(0, 8)
    return all
      .filter(
        (b) =>
          b.name.toLowerCase().includes(q) ||
          (b.aliases ?? []).some((a) => a.toLowerCase().includes(q)),
      )
      .slice(0, 8)
  }, [species, breedQuery])

  const conditionMatches = useMemo(() => {
    if (!species) return []
    const q = conditionQuery.trim().toLowerCase()
    const all = conditionsFor(species)
    return q ? all.filter((c) => c.name.toLowerCase().includes(q)) : all
  }, [species, conditionQuery])

  const weightNum = Number(weightLb) || 0
  const weightRead = breed && weightNum > 0 ? readBodyCondition(weightNum, breed) : null

  const canAdvance = (() => {
    switch (step) {
      case 0:
        return name.trim().length > 0 && species !== null
      case 1:
        return breedId !== null
      case 2:
        return birthDate !== '' && sex !== null && neutered !== null
      case 3:
        return weightNum > 0
      case 4:
        return true
      case 5:
        // Re-checked here: breedId can be cleared after step 1 by re-toggling
        // "Mixed / not sure", and a dead primary button is worse than a
        // disabled one.
        return breedId !== null
      default:
        return false
    }
  })()

  const submit = () => {
    if (!species || !breedId) return
    onComplete({
      id: `pet-${Date.now()}`,
      name: name.trim(),
      species,
      breedId,
      birthDate,
      sex: sex ?? 'female',
      neutered: neutered ?? true,
      weightLb: weightNum,
      conditionIds,
      activity,
      dental,
      diet,
    })
  }

  const next = () => (step === STEPS.length - 1 ? submit() : setStep((s) => s + 1))

  return (
    <div className="mx-auto w-full max-w-[620px] px-5 py-10 sm:py-16">
      <div className="mb-7 flex items-center justify-between gap-4">
        <div className="flex items-center gap-2.5">
          <CloverMark size={26} id="onb" />
          <span className="label">
            Step {step + 1} of {STEPS.length} · {STEPS[step]}
          </span>
        </div>
        {onCancel && (
          <button type="button" onClick={onCancel} className="text-[14px] text-muted underline underline-offset-4 hover:text-ink">
            Cancel
          </button>
        )}
      </div>

      <div className="mb-8 flex gap-1.5" aria-hidden="true">
        {STEPS.map((s, i) => (
          <span
            key={s}
            className={`h-1 flex-1 rounded-full transition-colors ${i <= step ? 'bg-forest' : 'bg-line'}`}
          />
        ))}
      </div>

      <div className="card p-6 sm:p-8">
        {step === 0 && (
          <div className="reveal space-y-6">
            <div>
              <h1 className="font-display text-[30px] leading-[1.15] text-ink sm:text-[34px]">
                Let's start with who we're planning for.
              </h1>
              <p className="mt-2 text-[15px] text-muted">Two questions, then we'll build the journey.</p>
            </div>
            <div>
              <label htmlFor="pet-name" className="label mb-2 block">
                Their name
              </label>
              <input
                id="pet-name"
                className="field"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Max"
                autoFocus
              />
            </div>
            <div>
              <span className="label mb-2 block">Dog or cat</span>
              <Segmented
                name="Species"
                value={species}
                onChange={(v) => {
                  setSpecies(v)
                  setBreedId(null)
                  setBreedQuery('')
                  setMixedSize(null)
                  setShowSizePicker(false)
                  setConditionIds([])
                }}
                options={[
                  { value: 'dog' as Species, label: 'Dog' },
                  { value: 'cat' as Species, label: 'Cat' },
                ]}
              />
            </div>
          </div>
        )}

        {step === 1 && species && (
          <div className="reveal space-y-5">
            <div>
              <h1 className="font-display text-[28px] leading-[1.18] text-ink sm:text-[32px]">
                What breed is {name.trim() || 'your pet'}?
              </h1>
              <p className="mt-2 text-[15px] text-muted">
                Breed is the single biggest input. If you're not sure, that's a fine answer too.
              </p>
            </div>

            <input
              className="field"
              value={breedQuery}
              onChange={(e) => {
                setBreedQuery(e.target.value)
                setBreedId(null)
                setShowSizePicker(false)
              }}
              placeholder="Start typing a breed…"
              aria-label="Search breeds"
              autoFocus
            />

            <div className="max-h-[268px] overflow-y-auto rounded-soft border border-line">
              {breedMatches.map((b) => (
                <button
                  key={b.id}
                  type="button"
                  onClick={() => {
                    setBreedId(b.id)
                    setBreedQuery(b.name)
                    setShowSizePicker(false)
                  }}
                  className={`flex w-full items-center justify-between gap-3 border-b border-line px-4 py-2.5 text-left text-[15px] last:border-b-0 transition ${
                    breedId === b.id ? 'bg-sage text-deep' : 'bg-white hover:bg-cream'
                  }`}
                >
                  <span>{b.name}</span>
                  <span className="text-[12.5px] capitalize text-muted">{b.sizeClass}</span>
                </button>
              ))}
              {breedMatches.length === 0 && (
                <p className="px-4 py-3 text-[14px] text-muted">
                  No match. Try "Mixed / not sure" below.
                </p>
              )}
            </div>

            <button
              type="button"
              onClick={() => {
                setShowSizePicker(true)
                setBreedId(null)
                setBreedQuery('')
                setMixedSize(null)
              }}
              className={`w-full rounded-soft border px-4 py-3 text-left text-[15px] transition ${
                showSizePicker ? 'border-forest bg-sage text-deep' : 'border-line bg-white hover:border-forest/50'
              }`}
            >
              Mixed / not sure
              <span className="mt-0.5 block text-[13px] text-muted">
                We'll use a size-based profile and widen the range to match what we don't know.
              </span>
            </button>

            {showSizePicker && species === 'dog' && (
              <div className="reveal">
                <span className="label mb-2 block">Roughly what size?</span>
                <div className="grid gap-2 sm:grid-cols-3">
                  {SIZE_LABELS.map((s) => (
                    <button
                      key={s.value}
                      type="button"
                      onClick={() => {
                        setMixedSize(s.value)
                        setBreedId(MIXED_BY_SIZE[s.value])
                      }}
                      className={`rounded-soft border px-3 py-2.5 text-left transition ${
                        mixedSize === s.value
                          ? 'border-forest bg-forest text-white'
                          : 'border-line bg-white hover:border-forest/50'
                      }`}
                    >
                      <span className="block text-[14.5px] font-medium">{s.label}</span>
                      <span className={`block text-[12px] ${mixedSize === s.value ? 'text-white/70' : 'text-muted'}`}>
                        {s.hint}
                      </span>
                    </button>
                  ))}
                </div>
              </div>
            )}

            {showSizePicker && species === 'cat' && (
              <div className="reveal grid gap-2 sm:grid-cols-2">
                {['domestic-shorthair', 'domestic-longhair'].map((id) => {
                  const b = findBreed(id)!
                  return (
                    <button
                      key={id}
                      type="button"
                      onClick={() => setBreedId(id)}
                      className={`rounded-soft border px-4 py-3 text-left text-[15px] transition ${
                        breedId === id ? 'border-forest bg-forest text-white' : 'border-line bg-white hover:border-forest/50'
                      }`}
                    >
                      {b.name}
                    </button>
                  )
                })}
              </div>
            )}
          </div>
        )}

        {step === 2 && (
          <div className="reveal space-y-6">
            <div>
              <h1 className="font-display text-[28px] leading-[1.18] text-ink sm:text-[32px]">
                When was {name.trim() || 'your pet'} born?
              </h1>
              <p className="mt-2 text-[15px] text-muted">An approximate date is fine.</p>
            </div>
            <div>
              <label htmlFor="dob" className="label mb-2 block">
                Date of birth
              </label>
              <input
                id="dob"
                type="date"
                className="field"
                value={birthDate}
                min="1995-01-01"
                max={new Date().toISOString().slice(0, 10)}
                onChange={(e) => setBirthDate(e.target.value)}
              />
            </div>
            <div>
              <span className="label mb-2 block">Sex</span>
              <Segmented
                name="Sex"
                value={sex}
                onChange={setSex}
                options={[
                  { value: 'female' as Sex, label: 'Female' },
                  { value: 'male' as Sex, label: 'Male' },
                ]}
              />
            </div>
            <div>
              <span className="label mb-2 block">Neutered or spayed</span>
              <Segmented
                name="Neuter status"
                value={neutered === null ? null : neutered ? 'yes' : 'no'}
                onChange={(v) => setNeutered(v === 'yes')}
                options={[
                  { value: 'yes', label: 'Yes' },
                  { value: 'no', label: 'No' },
                ]}
              />
            </div>
          </div>
        )}

        {step === 3 && (
          <div className="reveal space-y-6">
            <div>
              <h1 className="font-display text-[28px] leading-[1.18] text-ink sm:text-[32px]">
                What does {name.trim() || 'your pet'} weigh?
              </h1>
              <p className="mt-2 text-[15px] text-muted">
                This is the input that moves the projection most, so it's worth being roughly right.
              </p>
            </div>
            <div>
              <label htmlFor="weight" className="label mb-2 block">
                Current weight (lb)
              </label>
              <input
                id="weight"
                type="number"
                inputMode="decimal"
                min={1}
                max={400}
                className="field"
                value={weightLb}
                onChange={(e) => setWeightLb(e.target.value)}
                placeholder={breed ? String(Math.round((breed.weight.low + breed.weight.high) / 2)) : '40'}
                autoFocus
              />
            </div>
            {breed && (
              <div className="rounded-soft border border-line bg-cream/60 p-4">
                <p className="text-[13px] text-muted">
                  Typical adult range for {breed.name}:{' '}
                  <span className="font-medium text-ink">
                    {breed.weight.low}–{breed.weight.high} lb
                  </span>
                </p>
                {weightRead && (
                  <p className="mt-2 flex items-center gap-2 text-[14.5px]">
                    <span
                      className={`inline-block h-2 w-2 rounded-full ${
                        weightRead === 'ideal' ? 'bg-forest' : 'bg-accent'
                      }`}
                    />
                    <span className="font-medium text-ink">
                      {weightRead === 'ideal'
                        ? 'Within the typical range'
                        : weightRead === 'overweight'
                          ? 'Above the typical range'
                          : 'Below the typical range'}
                    </span>
                  </p>
                )}
              </div>
            )}
          </div>
        )}

        {step === 4 && species && (
          <div className="reveal space-y-5">
            <div>
              <h1 className="font-display text-[28px] leading-[1.18] text-ink sm:text-[32px]">
                Anything already diagnosed?
              </h1>
              <p className="mt-2 text-[15px] text-muted">
                Optional. Where something is already on the record, we move it from "watch for this" to
                "here's how it's managed".
              </p>
            </div>
            <input
              className="field"
              value={conditionQuery}
              onChange={(e) => setConditionQuery(e.target.value)}
              placeholder="Search conditions…"
              aria-label="Search conditions"
            />
            <div className="flex flex-wrap gap-2">
              {conditionMatches.map((c) => {
                const on = conditionIds.includes(c.id)
                return (
                  <button
                    key={c.id}
                    type="button"
                    aria-pressed={on}
                    onClick={() =>
                      setConditionIds((prev) =>
                        on ? prev.filter((x) => x !== c.id) : [...prev, c.id],
                      )
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
            {conditionIds.length === 0 && (
              <p className="text-[14px] text-muted">Nothing selected — that's the most common answer.</p>
            )}
          </div>
        )}

        {step === 5 && (
          <div className="reveal space-y-6">
            <div>
              <h1 className="font-display text-[28px] leading-[1.18] text-ink sm:text-[32px]">
                And day to day?
              </h1>
              <p className="mt-2 text-[15px] text-muted">
                These are the parts you can change. You'll be able to play with them in a moment.
              </p>
            </div>
            <div>
              <span className="label mb-2 block">Activity level</span>
              <Segmented
                name="Activity"
                value={activity}
                onChange={setActivity}
                options={[
                  { value: 'low' as ActivityLevel, label: 'Low', hint: 'Short or irregular' },
                  { value: 'moderate' as ActivityLevel, label: 'Moderate', hint: 'Daily, steady' },
                  { value: 'high' as ActivityLevel, label: 'High', hint: 'Long and varied' },
                ]}
              />
            </div>
            <div>
              <span className="label mb-2 block">Teeth cleaned at home</span>
              <Segmented
                name="Dental routine"
                value={dental}
                onChange={setDental}
                options={[
                  { value: 'daily' as DentalRoutine, label: 'Daily' },
                  { value: 'weekly' as DentalRoutine, label: 'Weekly' },
                  { value: 'rarely' as DentalRoutine, label: 'Rarely' },
                ]}
              />
            </div>
            <div>
              <span className="label mb-2 block">Feeding</span>
              <Segmented
                name="Diet quality"
                value={diet}
                onChange={setDiet}
                options={[
                  { value: 'measured' as DietQuality, label: 'Measured meals' },
                  { value: 'free-fed' as DietQuality, label: 'Free fed' },
                  { value: 'unsure' as DietQuality, label: 'Not sure' },
                ]}
              />
            </div>
          </div>
        )}

        <div className="mt-8 flex items-center justify-between gap-3 border-t border-line pt-6">
          <button
            type="button"
            onClick={() => setStep((s) => Math.max(0, s - 1))}
            disabled={step === 0}
            className="text-[15px] text-muted transition hover:text-ink disabled:cursor-not-allowed disabled:opacity-40"
          >
            Back
          </button>
          <button type="button" onClick={next} disabled={!canAdvance} className="pill-primary">
            {step === STEPS.length - 1 ? 'See the journey' : 'Continue'}
          </button>
        </div>
      </div>
    </div>
  )
}
