import { accuracyLine, planAccuracy } from '../engine/accuracy'
import { fitnessProvider, SIMULATED_DISCLOSURE } from '../fitness/provider'
import type { PetProfile, Projection } from '../data/types'
import { buildCoverage, buildHome, buildRewards } from '../engine/platform'
import { useState } from 'react'
import type { Surface } from './Nav'

function greeting() {
  const h = new Date().getHours()
  return h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening'
}

const R = 47
const CIRC = 2 * Math.PI * R

function ScoreRing({ value }: { value: number }) {
  return (
    <div className="shrink-0 text-center">
    <div className="relative mx-auto h-[118px] w-[118px]">
      <svg viewBox="0 0 118 118" className="h-full w-full -rotate-90">
        <defs>
          <linearGradient id="score-grad" x1="10%" y1="0%" x2="90%" y2="100%">
            <stop offset="0%" stopColor="#D98A26" />
            <stop offset="48%" stopColor="#8FA83E" />
            <stop offset="100%" stopColor="#1E7A46" />
          </linearGradient>
        </defs>
        <circle cx="59" cy="59" r={R} fill="none" stroke="#EDEAE0" strokeWidth={10} />
        <circle
          cx="59"
          cy="59"
          r={R}
          fill="none"
          stroke="url(#score-grad)"
          strokeWidth={10}
          strokeLinecap="round"
          strokeDasharray={CIRC}
          strokeDashoffset={CIRC * (1 - value / 100)}
        />
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center">
        <span className="font-display text-[36px] font-semibold leading-none text-ink">{value}</span>
        <span className="mt-0.5 text-[11px] leading-none text-muted">/ 100</span>
      </div>
    </div>
    <p className="mt-2 text-[10px] font-medium uppercase tracking-[0.12em] text-muted">
      Clovara Score
    </p>
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
}: {
  pet: PetProfile
  projection: Projection
  onNavigate: (s: Surface) => void
}) {
  const [scoreOpen, setScoreOpen] = useState(false)
  const accuracy = planAccuracy(pet)
  const h = buildHome(pet, projection)
  const rewards = buildRewards(pet, projection)
  const coverage = buildCoverage(pet, projection)
  const isCat = pet.species === 'cat'

  return (
    <div className="mx-auto w-full max-w-shell px-5 pb-24 pt-8 sm:pt-10">
      <header className="mb-6">
        <p className="text-[15px] text-muted">{greeting()}, Conor</p>
        <h1 className="mt-0.5 font-display text-[34px] leading-[1.1] text-ink sm:text-[40px]">
          {pet.name}'s day
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
              <h2 id="accuracy-heading" className="font-display text-[19px] leading-tight text-ink">
                {accuracyLine(pet.name, accuracy)}
              </h2>
              <span className="font-display text-[22px] font-semibold text-deep">
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
              <p className="mt-3 text-[14px] leading-relaxed text-ink/80">
                {accuracy.nextBest.benefit}
              </p>
            )}
            {accuracy.ceiling && (
              <p className="mt-2 text-[13px] leading-relaxed text-muted">
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
          {/* ── Score ─────────────────────────────────────────────────── */}
          <section className="card px-5 py-6 sm:px-6" aria-labelledby="score-heading">
            <div className="flex flex-wrap items-center gap-5 sm:flex-nowrap">
              <ScoreRing value={h.score.value} />
              <div className="min-w-[13rem] flex-1">
                <h2 id="score-heading" className="sr-only">
                  Clovara Score
                </h2>
                <span className="inline-flex items-center gap-1.5 rounded-full bg-sage px-3 py-1 text-[12.5px] font-medium text-deep">
                  {coverage.hasPolicy ? '✓ Coverage active' : 'No policy yet'}
                </span>
                <p className="mt-2.5 text-[14.5px] leading-relaxed text-ink/80">
                  {h.score.headline}
                </p>
                <button
                  type="button"
                  onClick={() => onNavigate('life')}
                  className="mt-2 text-[13.5px] text-forest hover:text-deep text-action"
                >
                  On track for {projection.healthyYearsRange.low.toFixed(1)}–
                  {projection.healthyYearsRange.high.toFixed(1)} healthy years
                </button>
              </div>
            </div>

            <div className="mt-5 grid gap-2.5 sm:grid-cols-2">
              <div className="rounded-soft bg-cream px-4 py-3">
                <p className="font-display text-[19px] font-semibold leading-none text-ink">
                  {h.steps.toLocaleString()}
                </p>
                <p className="mt-1 text-[12px] text-muted">
                  {isCat ? 'Active minutes' : 'Steps'} today · CloTag
                </p>
              </div>
              <div className="rounded-soft bg-cream px-4 py-3">
                <p className="font-display text-[19px] font-semibold leading-none text-ink">
                  {rewards.streaks[0].value}
                </p>
                <p className="mt-1 text-[12px] text-muted">Dental streak · {rewards.streaks[0].note}</p>
              </div>
            </div>

            <div className="mt-4 border-t border-line pt-4">
              <button
                type="button"
                onClick={() => setScoreOpen((o) => !o)}
                aria-expanded={scoreOpen}
                className="text-[13.5px] text-forest hover:text-deep text-action"
              >
                {scoreOpen ? 'Hide the breakdown' : 'What makes up the score'}
              </button>
              {scoreOpen && (
              <>
              <ul className="reveal mt-3 space-y-2.5">
                {h.score.bands.map((b) => (
                  <li key={b.id}>
                    <div className="flex items-baseline justify-between gap-3">
                      <span className="text-[14px] text-ink">{b.label}</span>
                      <span className="shrink-0 text-[13px] font-medium text-muted">
                        {b.earned}/{b.max}
                      </span>
                    </div>
                    <div className="mt-1 h-1.5 overflow-hidden rounded-full bg-line">
                      <div
                        className="h-full rounded-full bg-forest"
                        style={{ width: `${(b.earned / b.max) * 100}%` }}
                      />
                    </div>
                    <p className="mt-1 text-[12.5px] leading-snug text-muted">{b.detail}</p>
                  </li>
                ))}
              </ul>
              <p className="mt-3 text-[12.5px] leading-relaxed text-muted">
                The score is a product construct, not a clinical measure. It restates the same
                modifiable inputs that drive the healthy-years projection, weighted to match how
                strong the evidence behind each one is. It has not been validated against outcomes.
              </p>
              </>
              )}
            </div>
          </section>

          {/* ── Nudge ─────────────────────────────────────────────────── */}
          <section className="card border-l-[3px] border-l-accent bg-[#FBF4E7] px-5 py-5 sm:px-6">
            <p className="text-[11px] font-medium uppercase tracking-[0.14em] text-[#8A5510]">
              {h.nudge.eyebrow}
            </p>
            <h2 className="mt-1.5 text-[15.5px] font-medium leading-snug text-ink">
              {h.nudge.title}
            </h2>
            <p className="mt-1.5 text-[14px] leading-relaxed text-ink/75">{h.nudge.body}</p>
            <Sparkline points={h.stepsTrend} down={h.trendDown} />
            <button
              type="button"
              onClick={() => onNavigate('care')}
              className="mt-2 text-[13.5px] font-medium text-forest hover:text-deep text-action"
            >
              Ask the companion about it
            </button>
          </section>
        </div>

        <div className="space-y-5">
          {/* ── Coming up ─────────────────────────────────────────────── */}
          {h.comingUp && (
            <section className="card px-5 py-5 sm:px-6">
              <p className="label">Coming up</p>
              <div className="mt-3 flex items-start gap-3.5">
                <span
                  aria-hidden="true"
                  className="grid h-11 w-11 shrink-0 place-items-center rounded-soft bg-sage text-[19px]"
                >
                  💉
                </span>
                <div className="min-w-0 flex-1">
                  <p className="text-[14.5px] font-medium leading-snug text-ink">
                    {h.comingUp.title}
                  </p>
                  <p className="mt-0.5 text-[13px] leading-relaxed text-muted">
                    {h.comingUp.detail}
                  </p>
                  <button
                    type="button"
                    onClick={() => onNavigate('coverage')}
                    className="mt-1.5 text-[12.5px] font-medium text-forest hover:text-deep text-action"
                  >
                    Covered by the wellness rider
                  </button>
                </div>
              </div>
            </section>
          )}

          {/* ── This week's focus ─────────────────────────────────────── */}
          <section className="card px-5 py-5 sm:px-6">
            <p className="label">This week</p>
            <h2 className="mt-2 font-display text-[20px] leading-tight text-ink">
              {projection.currentStage.label} stage
            </h2>
            <p className="mt-1 text-[14px] leading-relaxed text-muted">
              {projection.currentStage.summary}
            </p>
            <ul className="mt-3 space-y-2">
              {projection.currentStage.recommendations.slice(0, 3).map((rec, i) => (
                <li key={i} className="flex gap-2.5 text-[13.5px] leading-relaxed text-ink/80">
                  <span aria-hidden="true" className="mt-[7px] h-[5px] w-[5px] shrink-0 rounded-full bg-forest" />
                  <span>{rec}</span>
                </li>
              ))}
            </ul>
            <button
              type="button"
              onClick={() => onNavigate('life')}
              className="mt-3 text-[13.5px] font-medium text-forest hover:text-deep text-action"
            >
              See the full life plan
            </button>
          </section>

          {/* ── Points ────────────────────────────────────────────────── */}
          <section className="card flex items-center gap-4 px-5 py-4 sm:px-6">
            <div className="min-w-0 flex-1">
              <p className="font-display text-[22px] font-semibold leading-none text-ink">
                {rewards.points.toLocaleString()}
              </p>
              <p className="mt-1 text-[13px] text-muted">
                Clovara points · +{rewards.weekPoints} this week
              </p>
            </div>
            <button
              type="button"
              onClick={() => onNavigate('rewards')}
              className="shrink-0 rounded-full border border-line px-4 py-2 text-[13.5px] font-medium text-ink transition hover:border-forest hover:text-forest"
            >
              Redeem
            </button>
          </section>
        </div>
      </div>

      {/* Both one tap from home, deliberately. Somebody frightened should not
          be navigating a menu. */}
      <a
        href="#/wrong"
        className="mt-6 flex items-center justify-between gap-3 rounded-soft border border-line bg-white px-4 py-3.5 transition hover:border-forest/50"
      >
        <span className="min-w-0">
          <span className="block text-[14.5px] font-medium text-ink">
            Something is wrong with {pet.name}
          </span>
          <span className="mt-0.5 block text-[13px] leading-relaxed text-muted">
            Describe it, and we will tell you if it is a ring-now.
          </span>
        </span>
        <span aria-hidden="true" className="shrink-0 text-[18px] leading-none text-muted">→</span>
      </a>

      {/* One tap from the home screen, deliberately. Somebody whose dog has
          just eaten something should not be navigating a menu. */}
      <a
        href="#/ate"
        className="mt-3 flex items-center justify-between gap-3 rounded-soft border border-line bg-white px-4 py-3.5 transition hover:border-forest/50"
      >
        <span className="min-w-0">
          <span className="block text-[14.5px] font-medium text-ink">
            {pet.name} ate something they shouldn&rsquo;t have
          </span>
          <span className="mt-0.5 block text-[13px] leading-relaxed text-muted">
            How urgent it is, and who to ring.
          </span>
        </span>
        <span aria-hidden="true" className="shrink-0 text-[18px] leading-none text-muted">
          →
        </span>
      </a>

      {/* Straight from the provider (SPEC §6.9). When a partner SDK lands,
          `simulated` goes false and this disclosure disappears on its own. */}
      {fitnessProvider().simulated && (
        <p className="mt-6 text-[13px] leading-relaxed text-muted">{SIMULATED_DISCLOSURE}</p>
      )}
    </div>
  )
}
