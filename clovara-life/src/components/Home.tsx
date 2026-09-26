import { accuracyLine, planAccuracy } from '../engine/accuracy'
import { fitnessProvider, SIMULATED_DISCLOSURE } from '../fitness/provider'
import { isRemembered } from '../engine/remember'
import { Briefing } from './Briefing'
import type { PetProfile, Projection } from '../data/types'
import { buildCoverage, buildHome, buildRewards } from '../engine/platform'
import { useState } from 'react'
import type { Surface } from './Nav'
import { Icon } from './Icon'

function greeting() {
  const h = new Date().getHours()
  return h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening'
}

const R = 47
const CIRC = 2 * Math.PI * R

/**
 * The score ring (DESIGN.md §5): track #EDEAE0, a 9px gradient stroke with round
 * caps — one of the few places the gradient is allowed — and a Playfair number.
 *
 * The micro-label sits INSIDE the ring on two centred lines. It used to sit on
 * one line underneath; §5 is explicit that a single line clips against the
 * stroke at any ring size, so the two-line form is the only one that holds.
 * Its max width is the inner diameter less 10px.
 *
 * "/ 100" is kept, though styleguide.html omits it: it is the only thing on the
 * page that says what the number is out of. The label is §5's ink-3, which
 * D-UI7 darkened to pass AA.
 */
const STROKE = 9
function ScoreRing({ value }: { value: number }) {
  const inner = 2 * (R - STROKE / 2)
  return (
    <div className="relative h-[118px] w-[118px] shrink-0">
      <svg viewBox="0 0 118 118" className="h-full w-full -rotate-90" aria-hidden="true">
        <defs>
          <linearGradient id="score-grad" x1="10%" y1="0%" x2="90%" y2="100%">
            <stop offset="0%" stopColor="#D98A26" />
            <stop offset="48%" stopColor="#8FA83E" />
            <stop offset="100%" stopColor="#1E7A46" />
          </linearGradient>
        </defs>
        <circle cx="59" cy="59" r={R} fill="none" stroke="#EDEAE0" strokeWidth={STROKE} />
        <circle
          cx="59"
          cy="59"
          r={R}
          fill="none"
          stroke="url(#score-grad)"
          strokeWidth={STROKE}
          strokeLinecap="round"
          strokeDasharray={CIRC}
          strokeDashoffset={CIRC * (1 - value / 100)}
        />
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center">
        <span className="font-display text-display-lg font-bold leading-none tabular-nums text-ink">{value}</span>
        <span className="mt-0.5 text-caption-sm leading-none tabular-nums text-ink-2">/ 100</span>
        <span
          className="mt-1.5 text-center text-micro font-semibold uppercase leading-[1.35] tracking-[0.1em] text-ink-3"
          style={{ maxWidth: inner - 10 }}
        >
          Clovara
          <br />
          Score
        </span>
      </div>
    </div>
  )
}

function Sparkline({ points, down }: { points: number[]; down: boolean }) {
  const max = Math.max(...points)
  const min = Math.min(...points)
  const span = Math.max(max - min, 1)
  const y = (v: number) => 4 + ((v - min) / span) * 26
  const d = points.map((p, i) => `${(i / (points.length - 1)) * 300},${y(p)}`).join(' ')
  const last = points[points.length - 1]
  return (
    <svg
      viewBox="0 0 300 34"
      preserveAspectRatio="none"
      className="mt-3 h-[34px] w-full"
      role="img"
      aria-label={`Seven day activity trend, ${down ? 'declining' : 'steady'}`}
    >
      <polyline
        points={d}
        fill="none"
        stroke={down ? '#D98A26' : '#1A5C38'}
        strokeWidth={2.5}
        strokeLinecap="round"
        strokeLinejoin="round"
        vectorEffect="non-scaling-stroke"
      />
      <circle cx={296} cy={y(last)} r={3.5} fill={down ? '#D98A26' : '#1A5C38'} />
    </svg>
  )
}

export function Home({
  pet,
  projection,
  onNavigate,
  greetName = null,
}: {
  pet: PetProfile
  projection: Projection
  onNavigate: (s: Surface) => void
  /** The signed-in person's first name; null greets nobody by name. */
  greetName?: string | null
}) {
  const [scoreOpen, setScoreOpen] = useState(false)
  const accuracy = planAccuracy(pet)
  const h = buildHome(pet, projection)
  const rewards = buildRewards(pet, projection)
  const coverage = buildCoverage(pet, projection)
  const isCat = pet.species === 'cat'
  // Nothing about how they are doing, once they have died (SPEC-HORIZON §2.5).
  const remembered = isRemembered(pet)

  return (
    <div className="mx-auto w-full max-w-shell px-5 pb-24 pt-8 sm:pt-10">
      <header className="mb-6">
        <p className="text-lead text-ink-2">
          {greeting()}
          {greetName ? `, ${greetName}` : ''}
        </p>
        {/* "{name}'s day" is present tense; once they have died it is just
            their name. */}
        <h1 className="mt-0.5 font-display text-display-lg leading-[1.1] text-ink sm:text-display-xl">
          {remembered ? pet.name : `${pet.name}'s day`}
        </h1>
      </header>

      {/* ── Plan accuracy (SPEC §4.2) — shown until the plan is >90% sharp ── */}
      {accuracy.showOnHome && (
        <section
          aria-labelledby="accuracy-heading"
          className="card mb-5 overflow-hidden border-forest/25 bg-sage/30"
        >
          <div className="px-5 py-4 sm:px-6">
            <div className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1">
              <h2 id="accuracy-heading" className="font-display text-heading-sm leading-tight text-ink">
                {accuracyLine(pet.name, accuracy)}
              </h2>
              <span className="font-display text-heading-lg font-semibold text-deep">
                {accuracy.score}%
              </span>
            </div>

            <div
              className="mt-3 h-1.5 w-full overflow-hidden rounded-full bg-white/70"
              role="progressbar"
              aria-valuenow={accuracy.score}
              aria-valuemin={0}
              aria-valuemax={100}
              aria-label={`${pet.name}'s plan accuracy`}
            >
              <div
                className="h-full rounded-full bg-forest transition-[width] duration-700 ease-out"
                style={{ width: `${accuracy.score}%` }}
              />
            </div>

            {accuracy.nextBest && (
              <p className="mt-3 text-body-lg leading-relaxed text-ink/80">
                {accuracy.nextBest.benefit}
              </p>
            )}
            {accuracy.ceiling && (
              <p className="mt-2 text-body-sm leading-relaxed text-ink-2">
                {accuracy.ceiling.reason}
              </p>
            )}
            {accuracy.nextBest && (
              <button
                type="button"
                onClick={() => onNavigate('life')}
                className="pill-primary mt-4"
              >
                Add {accuracy.nextBest.label}
              </button>
            )}
          </div>
        </section>
      )}

      <div className="grid gap-5 lg:grid-cols-[minmax(0,1.05fr)_minmax(0,1fr)] lg:items-start">
        <div className="space-y-5">
          <Briefing pet={pet} projection={projection} />

          {/* ── Score ─────────────────────────────────────────────────── */}
          {/* No score once they have died — buildHome returns none. The record
              stays one tap away instead. */}
          {remembered && (
            <button
              type="button"
              onClick={() => onNavigate('life')}
              className="flex w-full items-center justify-between gap-3 rounded-card border border-line bg-white px-5 py-4 text-left"
            >
              <span className="text-lead text-ink">{pet.name}&rsquo;s record</span>
              <Icon name="arrow-right" size={18} className="text-ink-2" />
            </button>
          )}
          {h.score && (
          <section className="card px-5 py-6 sm:px-6" aria-labelledby="score-heading">
            <div className="flex flex-wrap items-center gap-5 sm:flex-nowrap">
              <ScoreRing value={h.score.value} />
              <div className="min-w-[13rem] flex-1">
                <h2 id="score-heading" className="sr-only">
                  Clovara Score
                </h2>
                <span className={coverage?.hasPolicy ? 'chip-good' : 'chip-neutral'}>
                  {coverage?.hasPolicy ? (
                    <>
                      <Icon name="check" size={14} active />
                      Coverage active
                    </>
                  ) : (
                    'No policy yet'
                  )}
                </span>
                <p className="mt-2.5 text-body-lg leading-relaxed text-ink/80">
                  {h.score.headline}
                </p>
                <button
                  type="button"
                  onClick={() => onNavigate('life')}
                  className="mt-2 text-body text-forest hover:text-deep text-action"
                >
                  On track for {projection.healthyYearsRange.low.toFixed(1)}–{projection.healthyYearsRange.high.toFixed(1)} healthy years
                </button>
              </div>
            </div>

            {rewards && (
            <div className="mt-5 grid gap-2.5 sm:grid-cols-2">
              <div className="rounded-soft bg-cream px-4 py-3">
                <p className="font-display text-heading-sm font-semibold leading-none text-ink">
                  {h.steps.toLocaleString()}
                </p>
                <p className="mt-1 text-body-sm text-ink-2">
                  {isCat ? 'Active minutes' : 'Steps'} today · CloTag
                </p>
              </div>
              <div className="rounded-soft bg-cream px-4 py-3">
                <p className="font-display text-heading-sm font-semibold leading-none text-ink">
                  {rewards.streaks[0].value}
                </p>
                <p className="mt-1 text-body-sm text-ink-2">Dental streak · {rewards.streaks[0].note}</p>
              </div>
            </div>
            )}

            <div className="mt-4 border-t border-line pt-4">
              <button
                type="button"
                onClick={() => setScoreOpen((o) => !o)}
                aria-expanded={scoreOpen}
                className="text-body text-forest hover:text-deep text-action"
              >
                {scoreOpen ? 'Hide the breakdown' : 'What makes up the score'}
              </button>
              {scoreOpen && (
              <>
              <ul className="reveal mt-3 space-y-2.5">
                {h.score.bands.map((b) => (
                  <li key={b.id}>
                    <div className="flex items-baseline justify-between gap-3">
                      <span className="text-body-lg text-ink">{b.label}</span>
                      <span className="shrink-0 text-body-sm font-medium text-ink-2">
                        {b.earned}/{b.max}
                      </span>
                    </div>
                    <div className="mt-1 h-1.5 overflow-hidden rounded-full bg-line">
                      <div
                        className="h-full rounded-full bg-forest"
                        style={{ width: `${(b.earned / b.max) * 100}%` }}
                      />
                    </div>
                    <p className="mt-1 text-body-sm leading-snug text-ink-2">{b.detail}</p>
                  </li>
                ))}
              </ul>
              <p className="mt-3 text-body-sm leading-relaxed text-ink-2">
                The score is a product construct, not a clinical measure. It restates the same
                modifiable inputs that drive the healthy-years projection, weighted to match how
                strong the evidence behind each one is. It has not been validated against outcomes.
              </p>
              </>
              )}
            </div>
          </section>
          )}

          {/* ── Nudge ─────────────────────────────────────────────────── */}
          <section className="card border-l-[3px] border-l-accent bg-nudge-fill px-5 py-5 sm:px-6">
            <p className="text-caption font-semibold uppercase tracking-[0.18em] text-amber">
              {h.nudge.eyebrow}
            </p>
            <h2 className="mt-1.5 text-lead font-semibold leading-snug text-ink">
              {h.nudge.title}
            </h2>
            <p className="mt-1.5 text-body-lg leading-relaxed text-ink-2">{h.nudge.body}</p>
            {!remembered && (
              <>
                <Sparkline points={h.stepsTrend} down={h.trendDown} />
                <button
                  type="button"
                  onClick={() => onNavigate('care')}
                  className="mt-2 text-body font-medium text-forest hover:text-deep text-action"
                >
                  Ask the companion about it
                </button>
              </>
            )}
          </section>
        </div>

        <div className="space-y-5">
          {/* ── Coming up ─────────────────────────────────────────────── */}
          {h.comingUp && (
            <section className="card px-5 py-5 sm:px-6">
              <p className="label">Coming up</p>
              <div className="mt-3 flex items-start gap-3.5">
                {/* An outline calendar, not a syringe emoji: §5 allows emoji only as
                    content-image placeholders, and an event row's icon is UI (D-UI7). */}
                <span aria-hidden="true" className="grid h-11 w-11 shrink-0 place-items-center rounded-soft bg-sage text-deep">
                  <Icon name="calendar" size={22} />
                </span>
                <div className="min-w-0 flex-1">
                  <p className="text-body-lg font-medium leading-snug text-ink">
                    {h.comingUp.title}
                  </p>
                  <p className="mt-0.5 text-body-sm leading-relaxed text-ink-2">
                    {h.comingUp.detail}
                  </p>
                  <button
                    type="button"
                    onClick={() => onNavigate('coverage')}
                    className="mt-1.5 text-body-sm font-medium text-forest hover:text-deep text-action"
                  >
                    Covered by the wellness rider
                  </button>
                </div>
              </div>
            </section>
          )}

          {/* ── This week's focus ─────────────────────────────────────── */}
          <section className="card px-5 py-5 sm:px-6">
            {/* "This week" is present tense. For a pet who has died the same
                card is a record of the stage they reached. */}
            <p className="label">{remembered ? 'The stage they reached' : 'This week'}</p>
            <h2 className="mt-2 font-display text-heading leading-tight text-ink">
              {projection.currentStage.label} stage
            </h2>
            <p className="mt-1 text-body-lg leading-relaxed text-ink-2">
              {projection.currentStage.summary}
            </p>
            {/* The recommendations are advice for a living animal — the
                "suggestions" the Remember pass promises have stopped. */}
            {!remembered && (
            <ul className="mt-3 space-y-2">
              {projection.currentStage.recommendations.slice(0, 3).map((rec, i) => (
                <li key={i} className="flex gap-2.5 text-body leading-relaxed text-ink/80">
                  <span aria-hidden="true" className="mt-[7px] h-[5px] w-[5px] shrink-0 rounded-full bg-forest" />
                  <span>{rec}</span>
                </li>
              ))}
            </ul>
            )}
            {!remembered && (
            <button
              type="button"
              onClick={() => onNavigate('life')}
              className="mt-3 text-body font-medium text-forest hover:text-deep text-action"
            >
              See the full life plan
            </button>
            )}
          </section>

          {/* ── Points ────────────────────────────────────────────────── */}
          {rewards && (
          <section className="card flex items-center gap-4 px-5 py-4 sm:px-6">
            <div className="min-w-0 flex-1">
              <p className="font-display text-heading-lg font-semibold leading-none text-ink">
                {rewards.points.toLocaleString()}
              </p>
              <p className="mt-1 text-body-sm text-ink-2">
                Clovara points · +{rewards.weekPoints} this week
              </p>
            </div>
            <button
              type="button"
              onClick={() => onNavigate('rewards')}
              className="pill-ghost pill-sm shrink-0"
            >
              Redeem
            </button>
          </section>
          )}
        </div>
      </div>

      {/* Both one tap from home, deliberately. Somebody frightened should not
          be navigating a menu. */}
      {!remembered && (
        <>
      <a
        href="#/wrong"
        className="mt-6 flex items-center justify-between gap-3 rounded-soft border border-line bg-white px-4 py-3.5 transition hover:border-forest/50"
      >
        <span className="min-w-0">
          <span className="block text-body-lg font-medium text-ink">
            Something is wrong with {pet.name}
          </span>
          <span className="mt-0.5 block text-body-sm leading-relaxed text-ink-2">
            Describe it, and we will tell you if it is a ring-now.
          </span>
        </span>
        <Icon name="arrow-right" size={18} className="text-ink-2" />
      </a>

      {/* One tap from the home screen, deliberately. Somebody whose dog has
          just eaten something should not be navigating a menu. */}
      <a
        href="#/ate"
        className="mt-3 flex items-center justify-between gap-3 rounded-soft border border-line bg-white px-4 py-3.5 transition hover:border-forest/50"
      >
        <span className="min-w-0">
          <span className="block text-body-lg font-medium text-ink">
            {pet.name} ate something they shouldn&rsquo;t have
          </span>
          <span className="mt-0.5 block text-body-sm leading-relaxed text-ink-2">
            How urgent it is, and who to ring.
          </span>
        </span>
        <Icon name="arrow-right" size={18} className="text-ink-2" />
      </a>
        </>
      )}

      {/* Straight from the provider (SPEC §6.9). When a partner SDK lands,
          `simulated` goes false and this disclosure disappears on its own. */}
      {fitnessProvider().simulated && !remembered && (
        <p className="mt-6 text-body-sm leading-relaxed text-ink-2">{SIMULATED_DISCLOSURE}</p>
      )}
    </div>
  )
}
