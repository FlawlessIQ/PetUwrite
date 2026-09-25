import { useState } from 'react'
import type { BodyCondition, EvidenceTier, Lever, OutdoorAccess, Projection } from '../data/types'
import { EVIDENCE_LABELS } from '../data/engine'
import { Icon } from './Icon'

export interface LeverState {
  weight?: BodyCondition
  dental?: 'daily' | 'weekly' | 'rarely'
  activity?: 'low' | 'moderate' | 'high'
  /** Cats only — the lever is not rendered for a dog. */
  outdoor?: OutdoorAccess
}

const TIER_STYLE: Record<EvidenceTier, string> = {
  strong: 'border-forest/30 bg-sage text-deep',
  associational: 'border-accent/30 bg-[#F6E8D2] text-[#8A5510]',
  directional: 'border-line bg-cream text-ink-2',
}

function EvidenceBadge({ tier }: { tier: EvidenceTier }) {
  const [open, setOpen] = useState(false)
  return (
    <span className="relative shrink-0">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        aria-label={`${EVIDENCE_LABELS[tier].label}. ${EVIDENCE_LABELS[tier].blurb}`}
        className={`inline-flex min-h-[36px] items-center gap-1 rounded-full border px-3 py-1.5 text-[11px] font-medium transition ${TIER_STYLE[tier]}`}
      >
        {EVIDENCE_LABELS[tier].label}
        <Icon name="info" size={13} className="opacity-60" />
      </button>
      {open && (
        <span className="reveal absolute right-0 top-[calc(100%+6px)] z-10 block w-[220px] rounded-soft border border-line bg-white px-3 py-2 text-[12.5px] font-normal leading-relaxed text-ink shadow-lift">
          {EVIDENCE_LABELS[tier].blurb}
        </span>
      )}
    </span>
  )
}

export function Levers({
  projection,
  state,
  onChange,
  baseline,
}: {
  projection: Projection
  state: LeverState
  onChange: (s: LeverState) => void
  /** The projection with no overrides, so we can show what changed. */
  baseline: Projection
}) {
  const set = (lever: Lever, value: string) => {
    if (lever.id === 'weight') onChange({ ...state, weight: value as BodyCondition })
    if (lever.id === 'dental') onChange({ ...state, dental: value as LeverState['dental'] })
    if (lever.id === 'activity') onChange({ ...state, activity: value as LeverState['activity'] })
    if (lever.id === 'outdoor') onChange({ ...state, outdoor: value as OutdoorAccess })
  }

  const diff = projection.healthyYearsRange.low - baseline.healthyYearsRange.low
  const touched = Object.keys(state).length > 0 && Math.abs(diff) >= 0.05

  return (
    <section className="card overflow-hidden" aria-labelledby="levers-heading">
      <div className="border-b border-line bg-cream/50 px-5 py-4 sm:px-6">
        <h2 id="levers-heading" className="font-display text-[22px] leading-tight text-ink">
          What you can change
        </h2>
        <p className="mt-1 text-[14px] leading-snug text-ink-2">
          Move these and watch the projection respond. Each one is labelled with how strong the
          evidence behind it actually is.
        </p>
      </div>

      <div className="divide-y divide-line">
        {projection.levers.map((lever) => {
          const current = lever.current
          const active = lever.options.find((o) => o.value === current)
          return (
            <div key={lever.id} className="px-5 py-5 sm:px-6">
              <div className="mb-1 flex flex-wrap items-center justify-between gap-x-3 gap-y-1.5">
                <h3 className="text-[15px] font-medium text-ink">{lever.label}</h3>
                <EvidenceBadge tier={lever.evidenceTier} />
              </div>
              <p className="mb-3 text-[13.5px] leading-snug text-ink-2">{lever.question}</p>

              <div role="radiogroup" aria-label={lever.label} className="grid grid-cols-3 gap-2">
                {lever.options.map((o) => {
                  const on = o.value === current
                  return (
                    <button
                      key={o.value}
                      type="button"
                      role="radio"
                      aria-checked={on}
                      onClick={() => set(lever, o.value)}
                      className={`rounded-full border-[1.5px] px-2 py-2 text-[13.5px] font-medium transition ${
                        on
                          ? 'border-forest bg-sage text-deep'
                          : 'border-line bg-cream text-ink hover:border-forest/50'
                      }`}
                    >
                      {o.label}
                    </button>
                  )
                })}
              </div>

              {active && (
                <p className="mt-3 text-[13.5px] leading-relaxed text-ink-2">{active.note}</p>
              )}
              <p className="mt-2 text-[12.5px] leading-relaxed text-ink-2/80">{lever.evidenceNote}</p>
            </div>
          )
        })}
      </div>

      <div className="border-t border-line bg-cream/50 px-5 py-4 sm:px-6">
        {touched ? (
          <p className="text-[14.5px] text-ink">
            <span
              className={`mr-2 inline-flex items-center rounded-full px-2.5 py-0.5 text-[13px] font-semibold ${
                diff > 0 ? 'bg-sage text-deep' : 'bg-[#F6E8D2] text-[#8A5510]'
              }`}
            >
              {diff > 0 ? '+' : ''}
              {diff.toFixed(1)} years
            </span>
            against their current routine.
          </p>
        ) : (
          <p className="text-[14px] text-ink-2">
            Set to what you told us. Change any of the {projection.levers.length === 4 ? 'four' : 'three'} to see the
            projection move.
          </p>
        )}
        {Object.keys(state).length > 0 && (
          <button
            type="button"
            onClick={() => onChange({})}
            className="mt-2 text-[13.5px] text-forest hover:text-deep text-action"
          >
            Reset to their real routine
          </button>
        )}
      </div>
    </section>
  )
}
