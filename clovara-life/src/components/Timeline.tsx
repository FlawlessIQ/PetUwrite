import type { LifeStage, Projection } from '../data/types'

function stageRange(s: LifeStage) {
  const fmt = (n: number) => (n % 1 === 0 ? String(n) : n.toFixed(1))
  if (s.to === null) return `From ${fmt(s.from)} years`
  if (s.from === 0) return `Birth to ${fmt(s.to)} years`
  return `${fmt(s.from)} to ${fmt(s.to)} years`
}

const STATUS_COPY: Record<LifeStage['status'], string> = {
  past: 'Behind them',
  current: 'Where they are now',
  future: 'What comes next',
}

export function Timeline({ projection, name }: { projection: Projection; name: string }) {
  return (
    <section className="card overflow-hidden" aria-labelledby="timeline-heading">
      <div className="border-b border-line bg-cream/50 px-5 py-4 sm:px-6">
        <h2 id="timeline-heading" className="font-display text-heading-lg leading-tight text-ink">
          {name}'s life journey
        </h2>
        <p className="mt-1 text-body-lg leading-snug text-ink-2">
          What has happened, what matters now, and what to plan for — shaped by breed and age.
        </p>
      </div>

      <ol className="relative px-5 py-2 sm:px-6">
        {projection.stages.map((stage, i) => {
          const isCurrent = stage.status === 'current'
          const isPast = stage.status === 'past'
          const last = i === projection.stages.length - 1

          return (
            <li key={stage.id} className="relative pb-7 pl-8 pt-6 sm:pl-10">
              {/* Rail */}
              {!last && (
                <span
                  aria-hidden="true"
                  className={`absolute left-[6px] top-[34px] h-[calc(100%-18px)] w-[2px] sm:left-[9px] ${
                    isPast ? 'bg-forest/35' : 'bg-line'
                  }`}
                />
              )}
              {/* Node */}
              <span
                aria-hidden="true"
                className={`absolute left-0 top-[26px] grid h-[14px] w-[14px] place-items-center rounded-full sm:left-[3px] ${
                  isCurrent
                    ? 'bg-clover ring-4 ring-sage'
                    : isPast
                      ? 'bg-forest/45'
                      : 'border-2 border-line bg-white'
                }`}
              />

              <div className="flex flex-wrap items-baseline gap-x-3 gap-y-1">
                <h3
                  className={`font-display text-heading-sm leading-tight ${
                    isCurrent ? 'text-deep' : isPast ? 'text-ink-2' : 'text-ink'
                  }`}
                >
                  {stage.label}
                </h3>
                <span className="text-body-sm text-ink-2">{stageRange(stage)}</span>
                <span
                  className={`rounded-full px-2 py-0.5 text-body-sm font-semibold ${
                    isCurrent ? 'bg-sage text-deep' : 'text-ink-2'
                  }`}
                >
                  {STATUS_COPY[stage.status]}
                </span>
              </div>

              <p className={`mt-1.5 text-body-lg leading-relaxed ${isPast ? 'text-ink-2' : 'text-ink/80'}`}>
                {stage.summary}
              </p>

              <ul className="mt-3 space-y-2">
                {stage.recommendations.map((r, idx) => (
                  <li key={idx} className="flex gap-2.5 text-body-lg leading-relaxed text-ink/85">
                    <span
                      aria-hidden="true"
                      className={`mt-[8px] h-[5px] w-[5px] shrink-0 rounded-full ${
                        isCurrent ? 'bg-forest' : isPast ? 'bg-line' : 'bg-accent/70'
                      }`}
                    />
                    <span className={isPast ? 'text-ink-2' : undefined}>{r}</span>
                  </li>
                ))}
              </ul>
            </li>
          )
        })}
      </ol>
    </section>
  )
}
