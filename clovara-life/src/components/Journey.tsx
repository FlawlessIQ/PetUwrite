import { useMemo, useState } from 'react'
import type { PetProfile } from '../data/types'
import { project } from '../engine/project'
import { LifeArc } from './LifeArc'
import { Levers, type LeverState } from './Levers'
import { Methodology } from './Methodology'
import { RiskCards } from './RiskCards'
import { Timeline } from './Timeline'
import { Sharpen } from './Sharpen'
import { AnnualReview } from './AnnualReview'
import { ShareCard } from './ShareCard'
import { FirstNight } from './FirstNight'
import { reviewDue } from '../engine/review'
import { gotchaState } from '../engine/gotchaDay'
import { isRemembered } from '../engine/remember'
import { Remembering } from './Remembering'
import { PetAvatar } from './PetAvatar'
import { useTween } from './useTween'

/**
 * What the one Health File line says.
 *
 * COMPUTED FROM THE PET ALONE, ON PURPOSE. The obvious version called
 * `passportState` and `vaccineState` for "12 of 103 firsts" and "2 usually due
 * now" — and pulled a hundred and three socialisation stamps and the whole
 * vaccination schedule into the main bundle, which every signed-out visitor
 * downloads to look at a demo pet. Moving those surfaces off the page and
 * leaving their content in the download would have been half a job.
 *
 * So: counts of what this pet actually has, no denominators, no schedule.
 */
function fileSummary(pet: PetProfile): string {
  const bits: string[] = []
  const stamps = pet.socialStamps?.length ?? 0
  const shots = pet.vaccineRecords?.length ?? 0
  if (shots > 0) bits.push(`${shots} vaccination${shots === 1 ? '' : 's'} recorded`)
  if (stamps > 0) bits.push(`${stamps} first${stamps === 1 ? '' : 's'}`)
  if (bits.length === 0) return 'Vaccinations, socialisation, and a link for a sitter.'
  bits.push('sitter link')
  return bits.join(' · ')
}

function ageLabel(years: number) {
  if (years < 1) {
    const m = Math.max(1, Math.round(years * 12))
    return `${m} month${m === 1 ? '' : 's'} old`
  }
  const whole = Math.floor(years)
  return `${whole} year${whole === 1 ? '' : 's'} old`
}

export function Journey({
  pet,
  householdId = null,
  onUpdate,
  showArrival = false,
  onDismissArrival,
}: {
  pet: PetProfile
  householdId?: string | null
  /** Absent for demo pets — they are a fixed exhibit, not someone's record. */
  onUpdate?: (patch: Partial<PetProfile>) => void
  /** The Arrival Certificate, offered once at creation (SPEC §6.1). */
  showArrival?: boolean
  onDismissArrival?: () => void
}) {
  const [levers, setLevers] = useState<LeverState>({})
  /**
   * The annual review, and the question it sends someone to.
   *
   * Dismissal is session-only and deliberately not persisted: "not now" means
   * not now, and a pet whose review is a year overdue should be asked again on
   * the next visit rather than never.
   */
  const [reviewDismissed, setReviewDismissed] = useState(false)
  /** Gotcha Day (SPEC §6.7) — the same share pipeline as the certificate. */
  const [gotchaDismissed, setGotchaDismissed] = useState(false)
  const gotcha = gotchaState(pet, new Date())
  const remembered = isRemembered(pet)
  const [revisit, setRevisit] = useState<string | null>(null)
  const showReview = !!onUpdate && !reviewDismissed && reviewDue(pet, new Date())

  const baseline = useMemo(() => project(pet), [pet])
  const projection = useMemo(
    () => project(pet, { overrides: levers }),
    [pet, levers],
  )

  const { healthyYearsRange: range, breed } = projection
  // The incentive mechanic: the number travels when an answer lands.
  const lowShown = useTween(range.low)
  const highShown = useTween(range.high)
  const beyond = projection.ageYears >= baseline.breed.baseline.low

  return (
    <div className="mx-auto w-full max-w-shell px-5 pb-20 pt-8 sm:pt-10">
      {/* ── Hero ─────────────────────────────────────────────────────────── */}
      <header className="mb-6">
        <p className="label">
          {breed.name} · {ageLabel(projection.ageYears)} ·{' '}
          {pet.neutered ? (pet.sex === 'female' ? 'Spayed female' : 'Neutered male') : pet.sex === 'female' ? 'Female' : 'Male'}
        </p>
        <div className="mt-1.5 flex items-center gap-3.5">
          <PetAvatar pet={pet} size={56} />
          <h1 className="font-display text-[38px] leading-[1.08] text-ink sm:text-[46px]">
            {pet.name}
          </h1>
        </div>
        {pet.headline && (
          <p className="mt-2 max-w-[62ch] text-[15.5px] leading-relaxed text-muted">{pet.headline}</p>
        )}
      </header>

      <section className="card mb-5 overflow-hidden" aria-labelledby="projection-heading">
        <div className="grid gap-6 px-5 py-7 sm:px-8 lg:grid-cols-[minmax(0,320px)_minmax(0,1fr)] lg:gap-10">
          <div className="flex flex-col justify-center">
            <h2 id="projection-heading" className="label">
              Healthy years projection
            </h2>
            <p className="mt-2.5 font-display text-[17px] leading-snug text-muted">
              {pet.name} is on track for
            </p>
            <p className="mt-1 font-display text-[54px] font-semibold leading-none tracking-[-0.02em] sm:text-[62px]">
              <span className="gradient-text">
                {lowShown.toFixed(1)}–{highShown.toFixed(1)}
              </span>
            </p>
            <p className="mt-1.5 font-display text-[21px] leading-none text-ink">healthy years</p>
            <p className="mt-4 max-w-[42ch] text-[14px] leading-relaxed text-muted">
              {beyond
                ? `${pet.name} is already past the typical range for the breed. We've shifted the projection to reflect that rather than pretend it hasn't happened.`
                : 'A range, not a number. We widen it when we know less, and it moves when the things below move.'}
            </p>
          </div>

          <div className="flex flex-col justify-center border-t border-line pt-6 lg:border-l lg:border-t-0 lg:pl-10 lg:pt-0">
            <LifeArc projection={projection} />
            <p className="mt-1 text-center text-[13.5px] text-muted">
              Currently a <span className="font-medium text-deep">{projection.currentStage.label.toLowerCase()}</span>
              {' · '}
              {projection.weightRead}
            </p>
          </div>
        </div>
      </section>

      {/* ── Body ─────────────────────────────────────────────────────────── */}
      <div className="grid gap-5 lg:grid-cols-[minmax(0,1.15fr)_minmax(0,1fr)] lg:items-start">
        <div className="space-y-5">
          {/* Before everything else for the first 72 hours: at 2am nothing else
              on this screen matters. */}
          <FirstNight pet={pet} />
          {gotcha.active && !gotchaDismissed && !showArrival && (
            <ShareCard
              pet={pet}
              kind="gotcha"
              years={gotcha.years}
              breedName={projection.breed.name}
              ageLabel={ageLabel(projection.ageYears)}
              onClose={() => setGotchaDismissed(true)}
            />
          )}
          {showArrival && (
            <ShareCard
              pet={pet}
              kind="arrival"
              breedName={projection.breed.name}
              ageLabel={ageLabel(projection.ageYears)}
              onClose={() => onDismissArrival?.()}
            />
          )}
          {remembered && <Remembering pet={pet} onUpdate={onUpdate} />}
          {!remembered && (
          <>
          {/* One line to the Health File, in place of three cards. SPEC §4.3
              names the file; stacking its contents onto Life made this page
              fifteen screens for a new puppy. */}
          <a
            href={`#/health/${encodeURIComponent(pet.id)}`}
            className="flex items-center justify-between gap-3 rounded-card border border-line bg-white px-5 py-4 transition hover:border-forest/50"
          >
            <span className="min-w-0">
              <span className="block text-[15px] font-medium text-ink">{pet.name}&rsquo;s health file</span>
              <span className="mt-0.5 block text-[13px] leading-relaxed text-muted">
                {fileSummary(pet)}
              </span>
            </span>
            <span aria-hidden="true" className="shrink-0 text-[18px] leading-none text-muted">
              →
            </span>
          </a>

          {/* SPEC §5's primary entry point: the offer at the emotional peak of
              the reveal. A link rather than a modal — nothing is interrupted. */}
          <a
            href="#/protect"
            className="flex items-center justify-between gap-3 rounded-card border border-forest/25 bg-sage/40 px-5 py-4 transition hover:border-forest/50"
          >
            <span className="min-w-0">
              <span className="block font-display text-[17px] leading-snug text-deep">
                Protect {pet.name} from today
              </span>
              <span className="mt-0.5 block text-[13px] leading-relaxed text-muted">
                A price worked out from this plan — no form, and nothing you have already told us.
              </span>
            </span>
            <span aria-hidden="true" className="shrink-0 text-[18px] leading-none text-forest">
              →
            </span>
          </a>
          {showReview && onUpdate && (
            <AnnualReview
              pet={pet}
              currentRange={{ low: baseline.healthyYearsRange.low, high: baseline.healthyYearsRange.high }}
              onRevisit={setRevisit}
              onComplete={(patch) => {
                onUpdate(patch)
                setReviewDismissed(true)
              }}
              onDismiss={() => setReviewDismissed(true)}
            />
          )}
          {onUpdate && (
            <Sharpen
              pet={pet}
              householdId={householdId}
              onUpdate={onUpdate}
              revisitField={revisit}
            />
          )}
          </>
          )}
          {remembered && (
            <a
              href={`#/health/${encodeURIComponent(pet.id)}`}
              className="flex items-center justify-between gap-3 rounded-card border border-line bg-white px-5 py-4"
            >
              <span className="text-[15px] text-ink">{pet.name}&rsquo;s record</span>
              <span aria-hidden="true" className="text-[18px] leading-none text-muted">→</span>
            </a>
          )}
          <Timeline projection={projection} name={pet.name} />
        </div>
        <div className="space-y-5">
          {!remembered && (
            <Levers projection={projection} state={levers} onChange={setLevers} baseline={baseline} />
          )}
          <RiskCards projection={projection} name={pet.name} />
          <Methodology projection={projection} />
        </div>
      </div>
    </div>
  )
}
