import { useEffect, useMemo, useState } from 'react'
import { markOnboardingStart } from '../analytics/timing'
import type { Breed, PetProfile, Sex, SizeClass, Species } from '../data/types'
import { MIXED_BY_SIZE, SIZE_LABELS, breedsFor, findBreed } from '../data/engine'
import { CloverMark } from './CloverMark'

/**
 * Tier 0 — everything before the reveal (SPEC §4.1).
 *
 * Species → breed → name → age → sex. Five questions, one of them typed, and
 * then the plan. Nothing else is asked here: weight, conditions and the daily
 * routine all moved to Tier 1, where each one is asked on a screen that shows
 * what answering does (SPEC §4.2). The principle is "onboarding never ends",
 * and the corollary is that it barely begins.
 *
 * No account wall. The reveal is the hook, so it has to come before the ask.
 */
const STEPS = ['Pet', 'Breed', 'Name', 'Age', 'Sex'] as const

interface Props {
  onComplete: (pet: PetProfile) => void
  onCancel?: () => void
}

function Segmented<T extends string>({
  options,
  value,
  onChange,
  name,
  columns = 3,
}: {
  options: { value: T; label: string; hint?: string }[]
  value: T | null
  onChange: (v: T) => void
  name: string
  columns?: 2 | 3
}) {
  return (
    <div
      role="radiogroup"
      aria-label={name}
      className={`grid gap-2.5 ${columns === 2 ? 'sm:grid-cols-2' : 'sm:grid-cols-3'}`}
    >
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
              <span
                className={`mt-0.5 block text-[12.5px] leading-snug ${active ? 'text-white/70' : 'text-muted'}`}
              >
                {o.hint}
              </span>
            )}
          </button>
        )
      })}
    </div>
  )
}

/** "About 4 months" / "about 3 years" — how an owner actually holds this. */
function ageLabel(months: number): string {
  if (months < 1) return 'under a month'
  if (months < 24) return `${months} month${months === 1 ? '' : 's'}`
  const years = Math.floor(months / 12)
  const rem = months % 12
  if (rem === 0) return `${years} years`
  if (rem === 6) return `${years}½ years`
  return `${years} years, ${rem} month${rem === 1 ? '' : 's'}`
}

/** Months-ago → ISO date. Mid-month, since the whole point is that it is approximate. */
function birthDateFromMonths(months: number, now: Date): string {
  const d = new Date(now)
  d.setMonth(d.getMonth() - months)
  return d.toISOString().slice(0, 10)
}

export function Onboarding({ onComplete, onCancel }: Props) {
  // Starts the one stopwatch SPEC §4.1 implies with its sixty-second target.
  // Here rather than at app load: a page view is not an onboarding.
  useEffect(() => markOnboardingStart(), [])
  const [step, setStep] = useState(0)
  const [species, setSpecies] = useState<Species | null>(null)
  const [breedId, setBreedId] = useState<string | null>(null)
  const [breedQuery, setBreedQuery] = useState('')
  const [mixedSize, setMixedSize] = useState<SizeClass | null>(null)
  const [showSizePicker, setShowSizePicker] = useState(false)
  const [name, setName] = useState('')
  const [ageMonths, setAgeMonths] = useState(36)
  const [exactDate, setExactDate] = useState('')
  const [useExact, setUseExact] = useState(false)
  const [sex, setSex] = useState<Sex | null>(null)

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

  const canAdvance = (() => {
    switch (step) {
      case 0:
        return species !== null
      case 1:
        return breedId !== null
      case 2:
        return name.trim().length > 0
      case 3:
        return useExact ? exactDate !== '' : true
      case 4:
        // Re-checked: breedId can be cleared by re-opening "Mixed / not sure",
        // and a dead primary button is worse than a disabled one.
        return sex !== null && breedId !== null
      default:
        return false
    }
  })()

  const submit = () => {
    if (!species || !breedId || !sex) return
    const now = new Date()
    onComplete({
      id: `pet-${Date.now()}`,
      name: name.trim(),
      species,
      breedId,
      birthDate: useExact ? exactDate : birthDateFromMonths(ageMonths, now),
      ...(useExact ? {} : { birthDateApprox: true }),
      sex,
      // When we first knew them — the anchor for the annual review (SPEC
      // §4.3). Not the birthday: a nine-year-old rescue adopted last week has
      // been ours for a week, and asking "what changed this year?" on day one
      // would be a strange way to meet someone's dog.
      knownSince: now.toISOString(),
      // Tier 1 stays genuinely absent. Writing defaults here would tell the
      // accuracy meter we know things nobody has been asked (SPEC §4.2).
      weightLb: 0,
      conditionIds: [],
    })
  }

  const next = () => (step === STEPS.length - 1 ? submit() : setStep((s) => s + 1))
  const who = name.trim() || 'your pet'

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
          <button
            type="button"
            onClick={onCancel}
            className="text-[14px] text-muted underline underline-offset-4 hover:text-ink"
          >
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
        {/* ── 1. Species ──────────────────────────────────────────────── */}
        {step === 0 && (
          <div className="reveal space-y-6">
            <div>
              <h1 className="font-display text-[30px] leading-[1.15] text-ink sm:text-[34px]">
                Who are we planning for?
              </h1>
              <p className="mt-2 text-[15px] text-muted">
                Five quick questions and you'll see their plan. No account needed.
              </p>
            </div>
            <Segmented
              name="Species"
              columns={2}
              value={species}
              onChange={(v) => {
                setSpecies(v)
                setBreedId(null)
                setBreedQuery('')
                setMixedSize(null)
                setShowSizePicker(false)
              }}
              options={[
                { value: 'dog' as Species, label: 'A dog' },
                { value: 'cat' as Species, label: 'A cat' },
              ]}
            />
            {/* Invariant 5: linked from onboarding. Opens in a new tab so it
                cannot cost anyone the answers they have already given. */}
            <a
              href="#/covenant"
              target="_blank"
              rel="noreferrer"
              className="inline-block text-[13.5px] text-muted underline underline-offset-4 transition hover:text-ink"
            >
              Before you start: what we do and never do with what you tell us
            </a>
          </div>
        )}

        {/* ── 2. Breed ────────────────────────────────────────────────── */}
        {step === 1 && species && (
          <div className="reveal space-y-5">
            <div>
              <h1 className="font-display text-[28px] leading-[1.18] text-ink sm:text-[32px]">
                What breed?
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
                  className={`flex w-full items-center justify-between gap-3 border-b border-line px-4 py-2.5 text-left text-[15px] transition last:border-b-0 ${
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
                showSizePicker
                  ? 'border-forest bg-sage text-deep'
                  : 'border-line bg-white hover:border-forest/50'
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
                      <span
                        className={`block text-[12px] ${mixedSize === s.value ? 'text-white/70' : 'text-muted'}`}
                      >
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
                        breedId === id
                          ? 'border-forest bg-forest text-white'
                          : 'border-line bg-white hover:border-forest/50'
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

        {/* ── 3. Name ─────────────────────────────────────────────────── */}
        {step === 2 && (
          <div className="reveal space-y-6">
            <div>
              <h1 className="font-display text-[28px] leading-[1.18] text-ink sm:text-[32px]">
                What's their name?
              </h1>
              {breed && (
                <p className="mt-2 text-[15px] text-muted">
                  The only thing here you have to type.
                </p>
              )}
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
                onKeyDown={(e) => e.key === 'Enter' && canAdvance && next()}
                placeholder={species === 'cat' ? 'Luna' : 'Max'}
                autoFocus
              />
            </div>
          </div>
        )}

        {/* ── 4. Age ──────────────────────────────────────────────────── */}
        {step === 3 && (
          <div className="reveal space-y-6">
            <div>
              <h1 className="font-display text-[28px] leading-[1.18] text-ink sm:text-[32px]">
                How old is {who}?
              </h1>
              <p className="mt-2 text-[15px] text-muted">
                Roughly is genuinely fine — you can sharpen it later.
              </p>
            </div>

            {useExact ? (
              <div>
                <label htmlFor="dob" className="label mb-2 block">
                  Date of birth
                </label>
                <input
                  id="dob"
                  type="date"
                  className="field"
                  value={exactDate}
                  min="1995-01-01"
                  max={new Date().toISOString().slice(0, 10)}
                  onChange={(e) => setExactDate(e.target.value)}
                />
              </div>
            ) : (
              <div>
                <p className="font-display text-[34px] leading-none text-deep">
                  About {ageLabel(ageMonths)}
                </p>
                <label htmlFor="age-slider" className="sr-only">
                  Approximate age in months
                </label>
                <input
                  id="age-slider"
                  type="range"
                  min={0}
                  max={240}
                  step={1}
                  value={ageMonths}
                  onChange={(e) => setAgeMonths(Number(e.target.value))}
                  className="mt-5 w-full accent-[#1F5136]"
                />
                <div className="mt-1 flex justify-between text-[12.5px] text-muted">
                  <span>newborn</span>
                  <span>20 years</span>
                </div>
              </div>
            )}

            <button
              type="button"
              onClick={() => setUseExact((v) => !v)}
              className="text-[14px] text-forest underline underline-offset-4 hover:text-deep"
            >
              {useExact ? 'I only know roughly' : 'I know the exact date'}
            </button>
          </div>
        )}

        {/* ── 5. Sex ──────────────────────────────────────────────────── */}
        {step === 4 && (
          <div className="reveal space-y-6">
            <div>
              <h1 className="font-display text-[28px] leading-[1.18] text-ink sm:text-[32px]">
                Is {who} male or female?
              </h1>
              <p className="mt-2 text-[15px] text-muted">Last one. Then the plan.</p>
            </div>
            <Segmented
              name="Sex"
              columns={2}
              value={sex}
              onChange={setSex}
              options={[
                { value: 'female' as Sex, label: 'Female' },
                { value: 'male' as Sex, label: 'Male' },
              ]}
            />
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
            {step === STEPS.length - 1 ? `See ${who}'s plan` : 'Continue'}
          </button>
        </div>
      </div>
    </div>
  )
}
