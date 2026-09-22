import { useMemo, useState } from 'react'
import type { PetProfile } from '../data/types'
import { project } from '../engine/project'
import { LifeArc } from './LifeArc'
import { Levers, type LeverState } from './Levers'
import { Methodology } from './Methodology'
import { RiskCards } from './RiskCards'
import { Timeline } from './Timeline'

function ageLabel(years: number) {
  if (years < 1) {
    const m = Math.max(1, Math.round(years * 12))
    return `${m} month${m === 1 ? '' : 's'} old`
  }
  const whole = Math.floor(years)
  return `${whole} year${whole === 1 ? '' : 's'} old`
}

export function Journey({ pet }: { pet: PetProfile }) {
  const [levers, setLevers] = useState<LeverState>({})

  const baseline = useMemo(() => project(pet), [pet])
  const projection = useMemo(
    () => project(pet, { overrides: levers }),
    [pet, levers],
  )

  const { healthyYearsRange: range, breed } = projection
  const beyond = projection.ageYears >= baseline.breed.baseline.low

  return (
    <div className="mx-auto w-full max-w-shell px-5 pb-20 pt-8 sm:pt-10">
      {/* ── Hero ─────────────────────────────────────────────────────────── */}
      <header className="mb-6">
        <p className="label">
          {breed.name} · {ageLabel(projection.ageYears)} ·{' '}
          {pet.neutered ? (pet.sex === 'female' ? 'Spayed female' : 'Neutered male') : pet.sex === 'female' ? 'Female' : 'Male'}
        </p>
        <h1 className="mt-1.5 font-display text-[38px] leading-[1.08] text-ink sm:text-[46px]">
          {pet.name}
        </h1>
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
                {range.low.toFixed(1)}–{range.high.toFixed(1)}
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
          <Timeline projection={projection} name={pet.name} />
        </div>
        <div className="space-y-5">
          <Levers projection={projection} state={levers} onChange={setLevers} baseline={baseline} />
          <RiskCards projection={projection} name={pet.name} />
          <Methodology projection={projection} />
        </div>
      </div>
    </div>
  )
}
